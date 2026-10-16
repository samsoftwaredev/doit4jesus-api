import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { eventIdSchema, reviewEventSchema } from '@/lib/schemas/events';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ eventId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const eventId = eventIdSchema.parse((await context.params).eventId);
    const input = reviewEventSchema.parse(await readJson(request));
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase.schema('api').rpc('review_event', {
      p_event_id: eventId,
      p_decision: input.decision,
    });

    throwDatabaseError(error, 'Unable to review the event.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
