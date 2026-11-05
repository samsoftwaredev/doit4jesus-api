import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { weekdayCodes } from '@/lib/schemas/church';
import { createChurchSubscriptionSchema } from '@/lib/schemas/church-subscription';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const { data: subscriptions, error: subscriptionsError } = await supabase
      .schema('app')
      .from('church_subscriptions')
      .select('*')
      .eq('user_id', userId)
      .order('created_at');
    throwDatabaseError(
      subscriptionsError,
      'Unable to load church subscriptions.',
    );

    const subscriptionIds = (subscriptions ?? []).map((item) => item.id);
    const churchIds = (subscriptions ?? []).map((item) => item.church_id);
    const [serviceTypesResult, weekdaysResult, churchesResult] =
      subscriptionIds.length
        ? await Promise.all([
            supabase
              .schema('app')
              .from('church_subscription_service_types')
              .select('subscription_id, service_type')
              .in('subscription_id', subscriptionIds),
            supabase
              .schema('app')
              .from('church_subscription_weekdays')
              .select('subscription_id, weekday')
              .in('subscription_id', subscriptionIds),
            supabase
              .schema('app')
              .from('churches')
              .select(
                'id, name, address_line_1, address_line_2, city, region_name, postal_code, country_code, timezone, latitude, longitude, directory_verification_status, schedule_verified_at',
              )
              .in('id', churchIds),
          ])
        : [
            { data: [], error: null },
            { data: [], error: null },
            { data: [], error: null },
          ];
    throwDatabaseError(
      serviceTypesResult.error,
      'Unable to load selected service types.',
    );
    throwDatabaseError(
      weekdaysResult.error,
      'Unable to load selected notification weekdays.',
    );
    throwDatabaseError(
      churchesResult.error,
      'Unable to load subscribed churches.',
    );

    const churchesById = new Map(
      (churchesResult.data ?? []).map((church) => [church.id, church]),
    );
    return ok(
      (subscriptions ?? []).flatMap((subscription) => {
        const church = churchesById.get(subscription.church_id);
        if (!church) return [];
        return [
          {
            id: subscription.id,
            church: {
              id: church.id,
              name: church.name,
              address: {
                line1: church.address_line_1,
                line2: church.address_line_2,
                city: church.city,
                regionName: church.region_name,
                postalCode: church.postal_code,
                countryCode: church.country_code,
              },
              timezone: church.timezone,
              latitude: church.latitude,
              longitude: church.longitude,
              directoryVerificationStatus: church.directory_verification_status,
            },
            serviceTypes: (serviceTypesResult.data ?? [])
              .filter((item) => item.subscription_id === subscription.id)
              .map((item) => item.service_type),
            notificationWeekdays: (weekdaysResult.data ?? [])
              .filter((item) => item.subscription_id === subscription.id)
              .map((item) => weekdayCodes[item.weekday]),
            notificationTime: subscription.notification_time.slice(0, 5),
            scheduleStatus: church.schedule_verified_at
              ? 'verified'
              : 'pending',
            scheduleVerifiedAt: church.schedule_verified_at,
            createdAt: subscription.created_at,
            updatedAt: subscription.updated_at,
          },
        ];
      }),
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const input = createChurchSubscriptionSchema.parse(await readJson(request));
    const { data, error } = await supabase
      .schema('api')
      .rpc('create_church_subscription', {
        p_church_id: input.churchId,
        p_service_types: input.serviceTypes,
        p_notification_weekdays: input.notificationWeekdays.map((day) =>
          weekdayCodes.indexOf(day),
        ),
      });
    throwDatabaseError(error, 'Unable to create the church subscription.');
    return created(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
