import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_current_user_friend_invite');

    throwDatabaseError(error, 'Unable to load the friend invite.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
