import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  churchToRpcPayload,
  serviceTimesToRpcPayload,
} from '@/lib/churches/admin-rpc';
import { churchIdSchema } from '@/lib/schemas/church';
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
        p_church: church ? churchToRpcPayload(church) : {},
        p_service_times:
          input.decision === 'verified'
            ? serviceTimesToRpcPayload(input.serviceTimes)
            : [],
        p_reason: input.reason ?? null,
      });
    throwDatabaseError(error, 'Unable to review the church schedule.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
