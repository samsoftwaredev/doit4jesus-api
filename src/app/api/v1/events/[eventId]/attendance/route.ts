import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, noContent } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { eventIdSchema } from '@/lib/schemas/events';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ eventId: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const eventId = eventIdSchema.parse((await context.params).eventId);
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('rsvp_to_event', { p_event_id: eventId });

    throwDatabaseError(error, 'Unable to RSVP to the event.');
    return created(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function DELETE(request: Request, context: Context) {
  try {
    const eventId = eventIdSchema.parse((await context.params).eventId);
    const { supabase } = await requireUser(request);
    const { error } = await supabase
      .schema('api')
      .rpc('cancel_event_rsvp', { p_event_id: eventId });

    throwDatabaseError(error, 'Unable to cancel the event RSVP.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
