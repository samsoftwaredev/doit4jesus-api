import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, noContent } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ notificationId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const { notificationId } = await context.params;
    const { supabase, userId } = await requireUser(request);
    const { data, error } = await supabase
      .schema('app')
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('id', notificationId)
      .eq('user_id', userId)
      .select('id')
      .maybeSingle();

    throwDatabaseError(error, 'Unable to mark the notification as read.');
    if (!data) throw ApiError.notFound('The notification was not found.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
