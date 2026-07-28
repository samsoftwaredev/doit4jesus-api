import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  churchIdSchema,
  reviewChurchChangeRequestSchema,
} from '@/lib/schemas/church';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ requestId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const { requestId: rawRequestId } = await context.params;
    const requestId = churchIdSchema.parse(rawRequestId);
    const input = reviewChurchChangeRequestSchema.parse(
      await readJson(request),
    );
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('review_church_change_request', {
        p_request_id: requestId,
        p_decision: input.decision,
        p_rejection_reason: input.rejectionReason ?? null,
      });

    throwDatabaseError(error, 'Unable to review the church change request.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
