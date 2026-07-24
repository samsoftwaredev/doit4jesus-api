import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { parsePositiveInt } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const url = new URL(request.url);
    const limit = parsePositiveInt(url.searchParams.get('limit'), 20, 100);
    const unreadOnly = url.searchParams.get('unreadOnly') === 'true';
    const before = url.searchParams.get('before');

    let query = supabase
      .schema('app')
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(limit + 1);

    if (unreadOnly) query = query.is('read_at', null);
    if (before) query = query.lt('created_at', before);

    const { data, error } = await query;
    throwDatabaseError(error, 'Unable to load notifications.');

    const hasMore = (data ?? []).length > limit;
    const items = hasMore ? (data ?? []).slice(0, limit) : (data ?? []);

    return ok(
      items,
      {},
      {
        limit,
        hasMore,
        nextCursor: hasMore ? (items.at(-1)?.created_at ?? null) : null,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
