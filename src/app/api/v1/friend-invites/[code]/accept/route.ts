import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { friendInviteCodeSchema } from '@/lib/schemas/friends';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ code: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const code = friendInviteCodeSchema.parse((await context.params).code);
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('accept_friend_invite', { p_code: code });

    throwDatabaseError(error, 'Unable to accept the friend invite.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
