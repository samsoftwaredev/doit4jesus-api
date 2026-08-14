import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { userSearchQuerySchema } from '@/lib/schemas/users';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = userSearchQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase.schema('api').rpc('search_users', {
      p_query: query.q,
      p_limit: query.limit + 1,
      p_offset: query.offset,
    });

    throwDatabaseError(error, 'Unable to search users.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit).map((user) => ({
        username: user.username,
        avatarUrl: user.avatar_url,
        title: user.title,
        relationshipState: user.relationship_state,
      })),
      { headers: { 'Cache-Control': 'no-store' } },
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
