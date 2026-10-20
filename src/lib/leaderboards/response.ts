import type { Database } from '@/lib/supabase/types';

type LeaderboardEntry =
  Database['competition']['Tables']['leaderboard_entries']['Row'];

type LeaderboardProfile = Pick<
  Database['app']['Views']['leaderboard_profiles']['Row'],
  | 'user_id'
  | 'display_name'
  | 'username'
  | 'avatar_url'
  | 'title'
  | 'country_code'
  | 'saint_avatar_id'
>;

export function toLeaderboardResponseEntry(
  entry: LeaderboardEntry,
  profile: LeaderboardProfile | undefined,
  currentUserId: string,
  rosaryOnly: boolean,
) {
  const responseProfile = {
    user_id: profile?.user_id ?? entry.user_id,
    display_name: profile?.display_name ?? 'Private Player',
    username: profile?.username ?? null,
    avatar_url: profile?.avatar_url ?? null,
    title: profile?.title ?? null,
    countryCode: profile?.country_code ?? null,
    saintAvatarId: profile?.saint_avatar_id ?? null,
  };
  const common = {
    period_id: entry.period_id,
    user_id: entry.user_id,
    scope_type: entry.scope_type,
    scope_reference: entry.scope_reference,
    rank: entry.rank,
    rosaries_count: entry.rosaries_count,
    updated_at: entry.updated_at,
    isCurrentUser: entry.user_id === currentUserId,
    profile: responseProfile,
  };

  return rosaryOnly
    ? common
    : {
        ...common,
        points: entry.points,
        scripture_readings_count: entry.scripture_readings_count,
        prayers_count: entry.prayers_count,
      };
}
