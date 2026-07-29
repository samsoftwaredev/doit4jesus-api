import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { friendsQuerySchema } from '@/lib/schemas/friends';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = friendsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('api')
      .rpc('list_current_user_friends', {
        p_limit: query.limit + 1,
        p_offset: query.offset,
      });

    throwDatabaseError(error, 'Unable to load friends.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit).map((friend) => ({
        id: friend.friend_id,
        displayName: friend.display_name,
        username: friend.username,
        avatarUrl: friend.avatar_url,
        title: friend.title,
        totalXp: friend.total_xp,
        currentLevel: {
          levelNumber: friend.current_level,
          code: friend.level_code,
          name: friend.level_name,
        },
        rosaryTotal: friend.rosary_total,
        badgeCount: friend.badge_count,
        friendsSince: friend.friends_since,
      })),
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
