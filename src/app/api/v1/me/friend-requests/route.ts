import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import {
  friendRequestsQuerySchema,
  sendFriendRequestSchema,
} from '@/lib/schemas/friends';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = friendRequestsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('api')
      .rpc('list_current_user_friend_requests', {
        p_direction: query.direction,
        p_status: query.status,
        p_limit: query.limit + 1,
        p_offset: query.offset,
      });

    throwDatabaseError(error, 'Unable to load friend requests.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit).map((friendRequest) => ({
        id: friendRequest.id,
        status: friendRequest.status,
        direction: friendRequest.direction,
        createdAt: friendRequest.created_at,
        respondedAt: friendRequest.responded_at,
        cancelledAt: friendRequest.cancelled_at,
        user: {
          id: friendRequest.user_id,
          displayName: friendRequest.display_name,
          username: friendRequest.username,
          avatarUrl: friendRequest.avatar_url,
          title: friendRequest.title,
        },
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

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const input = sendFriendRequestSchema.parse(await readJson(request));
    const { data, error } = await supabase
      .schema('api')
      .rpc('send_current_user_friend_request', {
        p_username: input.username,
      });

    throwDatabaseError(error, 'Unable to send the friend request.');
    const result = data as { automatic?: boolean };
    return result.automatic ? ok(data) : created(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
