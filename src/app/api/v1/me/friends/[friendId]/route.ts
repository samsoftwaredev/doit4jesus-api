import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, noContent, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import {
  friendDetailsQuerySchema,
  friendIdSchema,
} from '@/lib/schemas/friends';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ friendId: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const friendId = friendIdSchema.parse((await context.params).friendId);
    const query = friendDetailsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_current_user_friend_details', {
        p_friend_id: friendId,
        p_include_rosary_streak: query.include === 'rosaryStreak',
      });

    throwDatabaseError(error, 'Unable to load friend details.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function DELETE(request: Request, context: Context) {
  try {
    const friendId = friendIdSchema.parse((await context.params).friendId);
    const { supabase } = await requireUser(request);
    const { error } = await supabase
      .schema('api')
      .rpc('unfriend_current_user', { p_friend_id: friendId });

    throwDatabaseError(error, 'Unable to unfriend this user.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
