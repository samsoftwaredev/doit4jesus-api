import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('mark_all_current_user_notifications_read');

    throwDatabaseError(error, 'Unable to mark notifications as read.');
    return ok({ updated: data ?? 0 });
  } catch (error) {
    return errorResponse(error, request);
  }
}
