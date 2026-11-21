import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { adminMetricUsersQuerySchema } from '@/lib/schemas/admin-metrics';

export const dynamic = 'force-dynamic';

/** Lists the accounts behind one admin metric card (administrators only). */
export async function GET(request: Request) {
  try {
    const query = adminMetricUsersQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_admin_metric_users', {
        p_metric: query.metric,
        p_filter: query.filter,
        p_limit: query.limit,
        p_offset: query.offset,
      });

    throwDatabaseError(error, 'Unable to load the users behind this metric.');
    return ok(data, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    return errorResponse(error, request);
  }
}
