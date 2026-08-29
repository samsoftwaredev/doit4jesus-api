import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_admin_app_metrics');

    throwDatabaseError(error, 'Unable to load administrator app metrics.');
    return ok(data, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return errorResponse(error, request);
  }
}
