import { ApiError } from '@/lib/api/errors'
import { errorResponse, ok } from '@/lib/api/response'
import { throwDatabaseError } from '@/lib/api/database'
import { requireUser } from '@/lib/auth/require-user'
import { leaderboardQuerySchema } from '@/lib/schemas/leaderboard'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request)
    const url = new URL(request.url)
    const query = leaderboardQuerySchema.parse(Object.fromEntries(url.searchParams.entries()))

    let periodQuery = supabase
      .schema('competition')
      .from('leaderboard_periods')
      .select('*')
      .eq('period_type', query.periodType)

    periodQuery = query.periodCode
      ? periodQuery.eq('code', query.periodCode)
      : periodQuery.in('status', ['active', 'finalized']).order('starts_at', { ascending: false })

    const { data: periods, error: periodError } = await periodQuery.limit(1)
    throwDatabaseError(periodError, 'Unable to load the leaderboard period.')
    const period = periods?.[0]
    if (!period) throw ApiError.notFound('No leaderboard period matches the request.')

    const { data: entries, error: entriesError, count } = await supabase
      .schema('competition')
      .from('leaderboard_entries')
      .select('*', { count: 'exact' })
      .eq('period_id', period.id)
      .eq('scope_type', query.scopeType)
      .eq('scope_reference', query.scopeReference)
      .order('rank', { ascending: true, nullsFirst: false })
      .order('points', { ascending: false })
      .range(query.offset, query.offset + query.limit - 1)

    throwDatabaseError(entriesError, 'Unable to load leaderboard entries.')
    const rows = entries ?? []
    const userIds = [...new Set(rows.map((entry) => entry.user_id))]

    const { data: profiles, error: profileError } = userIds.length
      ? await supabase
          .schema('app')
          .from('user_profiles')
          .select('user_id,display_name,username,avatar_url,title')
          .in('user_id', userIds)
      : { data: [], error: null }

    throwDatabaseError(profileError, 'Unable to load leaderboard profiles.')
    const profileMap = new Map((profiles ?? []).map((profile) => [profile.user_id, profile]))

    return ok(
      {
        period,
        entries: rows.map((entry) => ({
          ...entry,
          isCurrentUser: entry.user_id === userId,
          profile: profileMap.get(entry.user_id) ?? {
            user_id: entry.user_id,
            display_name: 'Private Player',
            username: null,
            avatar_url: null,
            title: null,
          },
        })),
      },
      {},
      { total: count ?? 0, limit: query.limit, offset: query.offset },
    )
  } catch (error) {
    return errorResponse(error, request)
  }
}
