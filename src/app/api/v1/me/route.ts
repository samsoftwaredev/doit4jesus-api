import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import {
  loadCurrentProfile,
  loadProfileLocation,
  toCurrentProfile,
} from '@/lib/profiles/current-profile';
import { updateProfileSchema } from '@/lib/schemas/profile';
import type { Database } from '@/lib/supabase/types';
import { assertUsernameAllowed } from '@/lib/usernames/moderation';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    return ok(await loadCurrentProfile(supabase, userId));
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function PATCH(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const input = updateProfileSchema.parse(await readJson(request));

    if (input.username !== undefined && input.username !== null) {
      assertUsernameAllowed(input.username);
    }

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
    const location = await loadProfileLocation(
      supabase,
      data.city_id,
      data.country_code,
    );
    return ok(toCurrentProfile(data, location));
  } catch (error) {
    return errorResponse(error, request);
  }
}
