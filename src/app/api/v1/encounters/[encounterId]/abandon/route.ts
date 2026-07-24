import { throwDatabaseError } from '@/lib/api/database';
import { requireIdempotencyKey } from '@/lib/api/idempotency';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { encounterIdSchema } from '@/lib/schemas/battle';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ encounterId: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const { encounterId: rawEncounterId } = await context.params;
    const encounterId = encounterIdSchema.parse(rawEncounterId);
    const { supabase } = await requireUser(request);
    const idempotencyKey = requireIdempotencyKey(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('abandon_demon_encounter', {
        p_encounter_id: encounterId,
        p_idempotency_key: idempotencyKey,
      });

    throwDatabaseError(error, 'Unable to abandon the encounter.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
