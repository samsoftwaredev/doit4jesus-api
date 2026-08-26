import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { adminPrayerIntentionsQuerySchema } from '@/lib/schemas/prayer-intention';

export const dynamic = 'force-dynamic';

function utcDayRange(date: string) {
  const startsAt = new Date(`${date}T00:00:00.000Z`);
  const endsAt = new Date(startsAt);
  endsAt.setUTCDate(endsAt.getUTCDate() + 1);

  return { startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString() };
}

function toResponse(row: {
  id: string;
  creator_id: string;
  title: string;
  description: string;
  symbol: string | null;
  status: string;
  reviewed_by: string | null;
  reviewed_at: string | null;
  expires_at: string | null;
  created_at: string;
}) {
  return {
    id: row.id,
    creatorId: row.creator_id,
    title: row.title,
    description: row.description,
    symbol: row.symbol,
    status: row.status,
    createdAt: row.created_at,
    reviewedBy: row.reviewed_by,
    reviewedAt: row.reviewed_at,
    expiresAt: row.expires_at,
  };
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const query = adminPrayerIntentionsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('prayer')
      .from('prayer_intentions')
      .select('*')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false });

    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);
    if (query.createdAt) {
      const { startsAt, endsAt } = utcDayRange(query.createdAt);
      dbQuery = dbQuery.gte('created_at', startsAt).lt('created_at', endsAt);
    }

    const { data, error } = await dbQuery.range(
      query.offset,
      query.offset + query.limit,
    );
    throwDatabaseError(error, 'Unable to load prayer intentions.');

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
