import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { toEventResponse } from '@/lib/events/presentation';
import { eventIdSchema } from '@/lib/schemas/events';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ eventId: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const eventId = eventIdSchema.parse((await context.params).eventId);
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('app')
      .from('event_cards')
      .select('*')
      .eq('id', eventId)
      .maybeSingle();

    throwDatabaseError(error, 'Unable to load the event.');
    if (!data) throw ApiError.notFound('The event was not found.');

    const { data: view, error: viewError } = await supabase
      .schema('api')
      .rpc('record_event_view', { p_event_id: eventId });
    throwDatabaseError(viewError, 'Unable to record the event view.');

    const viewResult = view as { viewCount: number };
    return ok(toEventResponse({ ...data, view_count: viewResult.viewCount }));
  } catch (error) {
    return errorResponse(error, request);
  }
}
