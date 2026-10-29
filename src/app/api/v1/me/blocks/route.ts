import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const { data: blocks, error } = await supabase
      .schema('app')
      .from('user_blocks')
      .select('blocked_user_id,created_at')
      .eq('blocker_id', userId)
      .order('created_at', { ascending: false });
    throwDatabaseError(error, 'Unable to load blocked accounts.');

    const ids = (blocks ?? []).map((block) => block.blocked_user_id);
    if (ids.length === 0) return ok([]);
    const { data: profiles, error: profilesError } = await createAdminClient()
      .schema('app')
      .from('user_profiles')
      .select('user_id,display_name,username,avatar_url')
      .in('user_id', ids);
    throwDatabaseError(profilesError, 'Unable to load blocked accounts.');
    const profilesById = new Map(
      (profiles ?? []).map((profile) => [profile.user_id, profile]),
    );
    return ok(
      (blocks ?? []).map((block) => {
        const profile = profilesById.get(block.blocked_user_id);
        return {
          userId: block.blocked_user_id,
          displayName: profile?.display_name ?? 'Deleted account',
          username: profile?.username ?? null,
          avatarUrl: profile?.avatar_url ?? null,
          blockedAt: block.created_at,
        };
      }),
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
