import { errorResponse, ok } from '@/lib/api/response'
import { throwDatabaseError } from '@/lib/api/database'
import { requireUser } from '@/lib/auth/require-user'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request)

    const [{ data: progress, error: progressError }, { data: levels, error: levelsError }] =
      await Promise.all([
        supabase
          .schema('competition')
          .from('user_progress')
          .select('*')
          .eq('user_id', userId)
          .single(),
        supabase
          .schema('competition')
          .from('level_definitions')
          .select('*')
          .eq('is_active', true)
          .order('level_number', { ascending: true }),
      ])

    throwDatabaseError(progressError, 'Unable to load progression.')
    throwDatabaseError(levelsError, 'Unable to load level definitions.')

    const current = levels.find((level) => level.level_number === progress.current_level) ?? null
    const next = levels.find((level) => level.level_number > progress.current_level) ?? null
    const currentFloor = current?.minimum_total_xp ?? 0
    const nextFloor = next?.minimum_total_xp ?? progress.total_xp
    const denominator = Math.max(1, nextFloor - currentFloor)
    const percentage = next
      ? Math.min(100, Math.max(0, ((progress.total_xp - currentFloor) / denominator) * 100))
      : 100

    return ok({
      totalXp: progress.total_xp,
      lifetimePoints: progress.lifetime_points,
      weeklyPoints: progress.weekly_points,
      yearlyPoints: progress.yearly_points,
      lastActivityAt: progress.last_activity_at,
      version: progress.version,
      currentLevel: current,
      nextLevel: next,
      levelProgressPercentage: Number(percentage.toFixed(2)),
      xpIntoCurrentLevel: Math.max(0, progress.total_xp - currentFloor),
      xpRequiredForNextLevel: next ? nextFloor - currentFloor : 0,
      updatedAt: progress.updated_at,
    })
  } catch (error) {
    return errorResponse(error, request)
  }
}
