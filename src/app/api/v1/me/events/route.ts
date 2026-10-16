import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { toEventResponse } from '@/lib/events/presentation';
import { myEventsQuerySchema } from '@/lib/schemas/events';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = myEventsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('app')
      .from('my_event_summaries')
      .select('*')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false });

    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);
    const { data, error } = await dbQuery.range(
      query.offset,
      query.offset + query.limit,
    );
    throwDatabaseError(error, 'Unable to load your events.');

    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    return ok(
      rows.slice(0, query.limit).map((row) => toEventResponse(row, true)),
      {},
      {
        limit: query.limit,
        offset: query.offset,
        hasMore,
        nextOffset: hasMore ? query.offset + query.limit : null,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
