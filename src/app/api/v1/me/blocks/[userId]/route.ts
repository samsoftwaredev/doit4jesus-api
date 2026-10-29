import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, noContent } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { userIdSchema } from '@/lib/schemas/community-safety';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ userId: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const blockedUserId = userIdSchema.parse((await context.params).userId);
    const { supabase, userId } = await requireUser(request);
    const { data, error } = await supabase
      .schema('app')
      .from('user_blocks')
      .upsert(
        { blocker_id: userId, blocked_user_id: blockedUserId },
        { onConflict: 'blocker_id,blocked_user_id' },
      )
      .select('blocked_user_id,created_at')
      .single();
    throwDatabaseError(error, 'Unable to block this account.');
    return created({
      userId: data.blocked_user_id,
      blockedAt: data.created_at,
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function DELETE(request: Request, context: Context) {
  try {
    const blockedUserId = userIdSchema.parse((await context.params).userId);
    const { supabase, userId } = await requireUser(request);
    const { error } = await supabase
      .schema('app')
      .from('user_blocks')
      .delete()
      .eq('blocker_id', userId)
      .eq('blocked_user_id', blockedUserId);
    throwDatabaseError(error, 'Unable to unblock this account.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
