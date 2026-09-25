import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, noContent } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { accountUserIdSchema } from '@/lib/schemas/users';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ userId: string }> };

export async function DELETE(request: Request, context: Context) {
  try {
    const userId = accountUserIdSchema.parse((await context.params).userId);
    const { supabase } = await requireAdmin(request);
    const { error } = await supabase
      .schema('api')
      .rpc('delete_user_account', { p_user_id: userId });

    throwDatabaseError(error, 'Unable to delete the account.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
