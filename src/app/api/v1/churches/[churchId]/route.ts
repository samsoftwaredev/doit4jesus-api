import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { getChurchLiveStatus, weekdayName } from '@/lib/churches/live-status';
import { churchIdSchema } from '@/lib/schemas/church';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ churchId: string }> };

function toLocalTime(value: string) {
  return value.slice(0, 5);
}

export async function GET(request: Request, context: Context) {
  try {
    const { churchId: rawChurchId } = await context.params;
    const churchId = churchIdSchema.parse(rawChurchId);
    const { supabase } = await requireUser(request);
    const { data: church, error: churchError } = await supabase
      .schema('app')
      .from('churches')
      .select('*')
      .eq('id', churchId)
      .eq('is_active', true)
      .maybeSingle();

    throwDatabaseError(churchError, 'Unable to load the church.');
    if (!church) throw ApiError.notFound('The church was not found.');

    const [dioceseResult, serviceTimesResult] = await Promise.all([
      church.diocese_id
        ? supabase
            .schema('app')
            .from('dioceses')
            .select('id, name, country_code')
            .eq('id', church.diocese_id)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      supabase
        .schema('app')
        .from('church_service_times')
        .select('*')
        .eq('church_id', church.id)
        .order('weekday')
        .order('starts_at'),
    ]);

    throwDatabaseError(
      dioceseResult.error,
      'Unable to load the church diocese.',
    );
    throwDatabaseError(
      serviceTimesResult.error,
      'Unable to load the church service times.',
    );

    const serviceTimes = serviceTimesResult.data ?? [];
    const schedule = serviceTimes.map((serviceTime) => ({
      id: serviceTime.id,
      serviceType: serviceTime.service_type,
      weekday: weekdayName(serviceTime.weekday),
      startTime: toLocalTime(serviceTime.starts_at),
      endTime: serviceTime.ends_at ? toLocalTime(serviceTime.ends_at) : null,
      usesDefaultOneHourDuration: serviceTime.ends_at === null,
    }));

    return ok({
      id: church.id,
      name: church.name,
      diocese: dioceseResult.data
        ? {
            id: dioceseResult.data.id,
            name: dioceseResult.data.name,
            countryCode: dioceseResult.data.country_code,
          }
        : null,
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
      schedule,
      liveStatus: getChurchLiveStatus(
        serviceTimes.map((serviceTime) => ({
          id: serviceTime.id,
          serviceType: serviceTime.service_type,
          weekday: serviceTime.weekday,
          startTime: serviceTime.starts_at,
          endTime: serviceTime.ends_at,
        })),
        church.timezone,
      ),
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
