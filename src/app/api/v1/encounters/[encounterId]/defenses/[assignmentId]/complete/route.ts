import { throwDatabaseError } from '@/lib/api/database';
import { requireIdempotencyKey } from '@/lib/api/idempotency';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import {
  defenseAssignmentIdSchema,
  encounterIdSchema,
} from '@/lib/schemas/battle';

export const dynamic = 'force-dynamic';

type Context = {
  params: Promise<{ encounterId: string; assignmentId: string }>;
};

export async function POST(request: Request, context: Context) {
  try {
    const { encounterId: rawEncounterId, assignmentId: rawAssignmentId } =
      await context.params;
    const encounterId = encounterIdSchema.parse(rawEncounterId);
    const assignmentId = defenseAssignmentIdSchema.parse(rawAssignmentId);
    const { supabase } = await requireUser(request);
    const idempotencyKey = requireIdempotencyKey(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('complete_demon_defense', {
        p_encounter_id: encounterId,
        p_assignment_id: assignmentId,
        p_idempotency_key: idempotencyKey,
      });

    throwDatabaseError(error, 'Unable to complete the defense.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
