import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { adminUserSearchQuerySchema } from '@/lib/schemas/users';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const query = adminUserSearchQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('search_admin_users', { p_query: query.q, p_limit: query.limit });

    throwDatabaseError(error, 'Unable to search user accounts.');
    return ok(
      (data ?? []).map((user) => ({
        id: user.id,
        email: user.email,
        status: user.status,
        createdAt: user.created_at,
        displayName: user.display_name,
        username: user.username,
        isProtectedAdmin: user.is_admin,
      })),
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
