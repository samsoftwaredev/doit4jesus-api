import { errorResponse, ok } from '@/lib/api/response'
import { throwDatabaseError } from '@/lib/api/database'
import { requireUser } from '@/lib/auth/require-user'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request)

    const [definitionsResult, earnedResult, progressResult] = await Promise.all([
      supabase
        .schema('competition')
        .from('badge_definitions')
        .select('*')
        .eq('is_active', true)
        .order('category'),
      supabase
        .schema('competition')
        .from('user_badges')
        .select('*')
        .eq('user_id', userId)
        .order('earned_at', { ascending: false }),
      supabase
        .schema('competition')
        .from('user_badge_progress')
        .select('*')
        .eq('user_id', userId),
    ])

    throwDatabaseError(definitionsResult.error, 'Unable to load badge definitions.')
    throwDatabaseError(earnedResult.error, 'Unable to load earned badges.')
    throwDatabaseError(progressResult.error, 'Unable to load badge progress.')

    const earnedByBadge = new Map<string, typeof earnedResult.data>()
    for (const earned of earnedResult.data ?? []) {
      const current = earnedByBadge.get(earned.badge_id) ?? []
      current.push(earned)
      earnedByBadge.set(earned.badge_id, current)
    }

    const progressByBadge = new Map(
      (progressResult.data ?? []).map((progress) => [progress.badge_id, progress]),
    )

    return ok(
      (definitionsResult.data ?? []).map((definition) => ({
        definition,
        earned: earnedByBadge.get(definition.id) ?? [],
        progress: progressByBadge.get(definition.id) ?? null,
      })),
    )
  } catch (error) {
    return errorResponse(error, request)
  }
}
