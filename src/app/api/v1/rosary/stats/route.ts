import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { getOptionalUser } from '@/lib/auth/optional-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await getOptionalUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_global_rosary_stats');

    throwDatabaseError(error, 'Unable to load global rosary statistics.');
    return ok(data, {
      headers: {
        'Cache-Control': 'private, no-store',
        Vary: 'Authorization, Cookie',
      },
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
