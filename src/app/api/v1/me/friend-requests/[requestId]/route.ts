import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, noContent, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import {
  friendRequestIdSchema,
  reviewFriendRequestSchema,
} from '@/lib/schemas/friends';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ requestId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const requestId = friendRequestIdSchema.parse(
      (await context.params).requestId,
    );
    const input = reviewFriendRequestSchema.parse(await readJson(request));
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('review_current_user_friend_request', {
        p_request_id: requestId,
        p_decision: input.decision,
      });

    throwDatabaseError(error, 'Unable to review the friend request.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function DELETE(request: Request, context: Context) {
  try {
    const requestId = friendRequestIdSchema.parse(
      (await context.params).requestId,
    );
    const { supabase } = await requireUser(request);
    const { error } = await supabase
      .schema('api')
      .rpc('cancel_current_user_friend_request', { p_request_id: requestId });

    throwDatabaseError(error, 'Unable to cancel the friend request.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
