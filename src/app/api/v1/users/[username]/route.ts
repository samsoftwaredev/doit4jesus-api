import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { publicUsernameSchema } from '@/lib/schemas/friends';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ username: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const username = publicUsernameSchema.parse(
      (await context.params).username,
    );
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_user_public_profile', { p_username: username });

    throwDatabaseError(error, 'Unable to load the user profile.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
