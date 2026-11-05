import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { churchIdSchema, weekdayCodes } from '@/lib/schemas/church';
import { reviewChurchScheduleSchema } from '@/lib/schemas/church-subscription';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ reviewId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const { reviewId: rawReviewId } = await context.params;
    const reviewId = churchIdSchema.parse(rawReviewId);
    const input = reviewChurchScheduleSchema.parse(await readJson(request));
    const { supabase } = await requireAdmin(request);
    const church = input.decision === 'verified' ? input.church : undefined;
    const { data, error } = await supabase
      .schema('api')
      .rpc('review_church_schedule_task', {
        p_review_id: reviewId,
        p_decision: input.decision,
        p_church: church
          ? {
              diocese_id: church.dioceseId,
              name: church.name,
              address_line_1: church.addressLine1,
              address_line_2: church.addressLine2,
              city: church.city,
              region_name: church.regionName,
              postal_code: church.postalCode,
              country_code: church.countryCode,
              timezone: church.timezone,
              latitude: church.latitude,
              longitude: church.longitude,
            }
          : {},
        p_service_times:
          input.decision === 'verified'
            ? input.serviceTimes.map((serviceTime) => ({
                service_type: serviceTime.serviceType,
                weekday: weekdayCodes.indexOf(serviceTime.weekday),
                starts_at: serviceTime.startTime,
                ends_at: serviceTime.endTime ?? null,
              }))
            : [],
        p_reason: input.reason ?? null,
      });
    throwDatabaseError(error, 'Unable to review the church schedule.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
