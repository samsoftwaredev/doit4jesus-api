import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_my_rosary_stats');

    throwDatabaseError(error, 'Unable to load rosary statistics.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
