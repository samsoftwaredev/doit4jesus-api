import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { requireUser } from '@/lib/auth/require-user';

export async function requireAdmin(request: Request) {
  const context = await requireUser(request);
  const { data, error } = await context.supabase
    .schema('app')
    .rpc('is_current_user_admin');

  throwDatabaseError(error, 'Unable to verify administrator access.');
  if (!data) throw ApiError.forbidden();

  return context;
}
