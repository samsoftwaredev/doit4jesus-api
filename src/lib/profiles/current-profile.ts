import { throwDatabaseError } from '@/lib/api/database';
import type { AuthenticatedContext } from '@/lib/auth/require-user';
import { getProfileSetup } from '@/lib/profiles/setup';
import type { Database } from '@/lib/supabase/types';

type Supabase = AuthenticatedContext['supabase'];
type UserProfile = Database['app']['Tables']['user_profiles']['Row'];
type ProfileCity = Pick<
  Database['app']['Tables']['cities']['Row'],
  'country_code' | 'name' | 'region_name'
>;
type ProfileCountry = Pick<
  Database['app']['Tables']['countries']['Row'],
  'name'
>;

export type ProfileLocation = {
  city: ProfileCity | null;
  country: ProfileCountry | null;
};

export async function loadProfileLocation(
  supabase: Supabase,
  cityId: string | null,
  countryCode: string | null,
): Promise<ProfileLocation> {
  const [cityResult, countryResult] = await Promise.all([
    cityId
      ? supabase
          .schema('app')
          .from('cities')
          .select('name, region_name, country_code')
          .eq('id', cityId)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    countryCode
      ? supabase
          .schema('app')
          .from('countries')
          .select('name')
          .eq('code', countryCode)
          .maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ]);

  throwDatabaseError(
    cityResult.error,
    'Unable to load the current profile city.',
  );
  throwDatabaseError(
    countryResult.error,
    'Unable to load the current profile country.',
  );

  return { city: cityResult.data, country: countryResult.data };
}

export function toCurrentProfile(
  row: UserProfile,
  { city, country }: ProfileLocation,
) {
  return {
    userId: row.user_id,
    displayName: row.display_name,
    username: row.username,
    avatarUrl: row.avatar_url,
    title: row.title,
    gender: row.gender,
    saintAvatarId: row.saint_avatar_id,
    preferredLanguage: row.preferred_language,
    timezone: row.timezone,
    cityId: row.city_id,
    cityName: city?.name ?? null,
    state: city?.region_name ?? null,
    countryCode: row.country_code,
    countryName: country?.name ?? null,
    leaderboardVisibility: row.leaderboard_visibility,
    prayerMapVisibility: row.prayer_map_visibility,
    profileSetup: getProfileSetup({
      displayName: row.display_name,
      gender: row.gender,
      countryCode: row.country_code,
      cityId: row.city_id,
      countryExists: country !== null,
      cityCountryCode: city?.country_code ?? null,
      completedAt: row.profile_setup_completed_at,
    }),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function loadCurrentProfile(supabase: Supabase, userId: string) {
  const { data, error } = await supabase
    .schema('app')
    .from('user_profiles')
    .select('*')
    .eq('user_id', userId)
    .single();

  throwDatabaseError(error, 'Unable to load the current profile.');
  const location = await loadProfileLocation(
    supabase,
    data.city_id,
    data.country_code,
  );
  return toCurrentProfile(data, location);
}
