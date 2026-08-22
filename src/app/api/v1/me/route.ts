import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import {
  type AuthenticatedContext,
  requireUser,
} from '@/lib/auth/require-user';
import { updateProfileSchema } from '@/lib/schemas/profile';
import type { Database } from '@/lib/supabase/types';

export const dynamic = 'force-dynamic';

type UserProfile = Database['app']['Tables']['user_profiles']['Row'];
type ProfileCity = Pick<
  Database['app']['Tables']['cities']['Row'],
  'name' | 'region_name'
>;

async function getProfileCity(
  supabase: AuthenticatedContext['supabase'],
  cityId: string | null,
): Promise<ProfileCity | null> {
  if (!cityId) return null;

  const { data, error } = await supabase
    .schema('app')
    .from('cities')
    .select('name, region_name')
    .eq('id', cityId)
    .maybeSingle();

  throwDatabaseError(error, 'Unable to load the current profile city.');
  return data;
}

function toProfile(row: UserProfile, city: ProfileCity | null) {
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
    leaderboardVisibility: row.leaderboard_visibility,
    prayerMapVisibility: row.prayer_map_visibility,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const { data, error } = await supabase
      .schema('app')
      .from('user_profiles')
      .select('*')
      .eq('user_id', userId)
      .single();

    throwDatabaseError(error, 'Unable to load the current profile.');
    const city = await getProfileCity(supabase, data.city_id);
    return ok(toProfile(data, city));
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function PATCH(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const input = updateProfileSchema.parse(await readJson(request));

    const sanitized: Database['app']['Tables']['user_profiles']['Update'] = {};
    if (input.displayName !== undefined)
      sanitized.display_name = input.displayName;
    if (input.username !== undefined) sanitized.username = input.username;
    if (input.avatarUrl !== undefined) sanitized.avatar_url = input.avatarUrl;
    if (input.title !== undefined) sanitized.title = input.title;
    if (input.gender !== undefined) sanitized.gender = input.gender;
    if (input.saintAvatarId !== undefined)
      sanitized.saint_avatar_id = input.saintAvatarId;
    if (input.preferredLanguage !== undefined)
      sanitized.preferred_language = input.preferredLanguage;
    if (input.timezone !== undefined) sanitized.timezone = input.timezone;
    if (input.cityId !== undefined) sanitized.city_id = input.cityId;
    if (input.countryCode !== undefined)
      sanitized.country_code = input.countryCode;
    if (input.leaderboardVisibility !== undefined) {
      sanitized.leaderboard_visibility = input.leaderboardVisibility;
    }
    if (input.prayerMapVisibility !== undefined) {
      sanitized.prayer_map_visibility = input.prayerMapVisibility;
    }

    const { data, error } = await supabase
      .schema('app')
      .from('user_profiles')
      .update(sanitized)
      .eq('user_id', userId)
      .select('*')
      .single();

    throwDatabaseError(error, 'Unable to update the profile.');
    const city = await getProfileCity(supabase, data.city_id);
    return ok(toProfile(data, city));
  } catch (error) {
    return errorResponse(error, request);
  }
}
