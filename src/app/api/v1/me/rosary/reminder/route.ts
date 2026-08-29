import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_my_daily_rosary_reminder');

    throwDatabaseError(error, 'Unable to load the daily Rosary reminder.');
    return ok(data, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return errorResponse(error, request);
  }
}
