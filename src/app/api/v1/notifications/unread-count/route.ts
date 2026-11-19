import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_current_user_unread_notification_count');

    throwDatabaseError(error, 'Unable to load the notification count.');
    return ok({ count: data ?? 0 });
  } catch (error) {
    return errorResponse(error, request);
  }
}
