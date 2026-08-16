import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { friendsComparisonQuerySchema } from '@/lib/schemas/friends';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = friendsComparisonQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_current_user_friends_comparison', {
        p_period_type: query.periodType,
        p_period_code: query.periodCode ?? null,
        p_limit: query.limit,
        p_offset: query.offset,
      });

    throwDatabaseError(error, 'Unable to load the friends comparison.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
