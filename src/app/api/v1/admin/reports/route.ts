import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { adminReportsQuerySchema } from '@/lib/schemas/community-safety';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const query = adminReportsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('app')
      .from('content_reports')
      .select('*')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false });
    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);
    const { data, error } = await dbQuery.range(
      query.offset,
      query.offset + query.limit,
    );
    throwDatabaseError(error, 'Unable to load safety reports.');
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
