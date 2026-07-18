import { errorResponse, ok } from '@/lib/api/response'
import { readJson } from '@/lib/api/validation'
import { throwDatabaseError } from '@/lib/api/database'
import { requireUser } from '@/lib/auth/require-user'
import { updateProfileSchema } from '@/lib/schemas/profile'
import type { Database } from '@/lib/supabase/types'

export const dynamic = 'force-dynamic'

function toProfile(row: Record<string, unknown>) {
  return {
    userId: row.user_id,
    displayName: row.display_name,
    username: row.username,
    avatarUrl: row.avatar_url,
    title: row.title,
    preferredLanguage: row.preferred_language,
    timezone: row.timezone,
    cityId: row.city_id,
    countryCode: row.country_code,
    leaderboardVisibility: row.leaderboard_visibility,
    prayerMapVisibility: row.prayer_map_visibility,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request)
    const { data, error } = await supabase
      .schema('app')
      .from('user_profiles')
      .select('*')
      .eq('user_id', userId)
      .single()

    throwDatabaseError(error, 'Unable to load the current profile.')
    return ok(toProfile(data as unknown as Record<string, unknown>))
  } catch (error) {
    return errorResponse(error, request)
  }
}

export async function PATCH(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request)
    const input = updateProfileSchema.parse(await readJson(request))

    const sanitized: Database['app']['Tables']['user_profiles']['Update'] = {}
    if (input.displayName !== undefined) sanitized.display_name = input.displayName
    if (input.username !== undefined) sanitized.username = input.username
    if (input.avatarUrl !== undefined) sanitized.avatar_url = input.avatarUrl
    if (input.title !== undefined) sanitized.title = input.title
    if (input.preferredLanguage !== undefined) sanitized.preferred_language = input.preferredLanguage
    if (input.timezone !== undefined) sanitized.timezone = input.timezone
    if (input.cityId !== undefined) sanitized.city_id = input.cityId
    if (input.countryCode !== undefined) sanitized.country_code = input.countryCode
    if (input.leaderboardVisibility !== undefined) {
      sanitized.leaderboard_visibility = input.leaderboardVisibility
    }
    if (input.prayerMapVisibility !== undefined) {
      sanitized.prayer_map_visibility = input.prayerMapVisibility
    }

    const { data, error } = await supabase
      .schema('app')
      .from('user_profiles')
      .update(sanitized)
      .eq('user_id', userId)
      .select('*')
      .single()

    throwDatabaseError(error, 'Unable to update the profile.')
    return ok(toProfile(data as unknown as Record<string, unknown>))
  } catch (error) {
    return errorResponse(error, request)
  }
}
