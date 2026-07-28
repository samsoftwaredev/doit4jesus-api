import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { churchChangeRequestQuerySchema } from '@/lib/schemas/church';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const url = new URL(request.url);
    const query = churchChangeRequestQuerySchema.parse(
      Object.fromEntries(url.searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('app')
      .from('church_change_requests')
      .select('*')
      .order('created_at', { ascending: false })
      .range(query.offset, query.offset + query.limit);

    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);

    const { data, error } = await dbQuery;
    throwDatabaseError(error, 'Unable to load church change requests.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit),
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
