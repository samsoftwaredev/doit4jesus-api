import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { contactRequestAdminQuerySchema } from '@/lib/schemas/contact';

export const dynamic = 'force-dynamic';

function utcDayRange(date: string) {
  const startsAt = new Date(`${date}T00:00:00.000Z`);
  const endsAt = new Date(startsAt);
  endsAt.setUTCDate(endsAt.getUTCDate() + 1);

  return { startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString() };
}

function escapeLike(value: string) {
  return value.replace(/[\\%_]/g, '\\$&');
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const query = contactRequestAdminQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('app')
      .from('contact_requests')
      .select('*')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false });

    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);
    if (query.created_at) {
      const { startsAt, endsAt } = utcDayRange(query.created_at);
      dbQuery = dbQuery.gte('created_at', startsAt).lt('created_at', endsAt);
    }
    if (query.email) dbQuery = dbQuery.ilike('email', escapeLike(query.email));
    if (query.name)
      dbQuery = dbQuery.ilike('name', `%${escapeLike(query.name)}%`);
    if (query.subject) dbQuery = dbQuery.eq('subject', query.subject);

    const { data, error } = await dbQuery.range(
      query.offset,
      query.offset + query.limit,
    );

    throwDatabaseError(error, 'Unable to load contact requests.');
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
