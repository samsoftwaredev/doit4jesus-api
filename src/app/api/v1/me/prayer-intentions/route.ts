import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { myPrayerIntentionsQuerySchema } from '@/lib/schemas/prayer-intention';

export const dynamic = 'force-dynamic';

function toResponse(row: {
  id: string;
  title: string;
  description: string;
  symbol: string | null;
  status: string;
  created_at: string;
  reviewed_at: string | null;
  expires_at: string | null;
  prayer_count: number;
}) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    symbol: row.symbol,
    status: row.status,
    createdAt: row.created_at,
    reviewedAt: row.reviewed_at,
    expiresAt: row.expires_at,
    prayerCount: row.prayer_count,
  };
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = myPrayerIntentionsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('prayer')
      .from('my_prayer_intention_summaries')
      .select('*')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false });

    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);

    const { data, error } = await dbQuery.range(
      query.offset,
      query.offset + query.limit,
    );
    throwDatabaseError(error, 'Unable to load your prayer intentions.');

    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    return ok(
      rows.slice(0, query.limit).map(toResponse),
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
