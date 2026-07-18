import { ApiError } from '@/lib/api/errors'
import { throwDatabaseError } from '@/lib/api/database'
import { created, errorResponse, ok } from '@/lib/api/response'
import { parsePositiveInt, readJson } from '@/lib/api/validation'
import { requireUser } from '@/lib/auth/require-user'
import { recordActivitySchema } from '@/lib/schemas/activity'
import type { Json } from '@/lib/supabase/types'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request)
    const url = new URL(request.url)
    const limit = parsePositiveInt(url.searchParams.get('limit'), 20, 100)
    const before = url.searchParams.get('before')
    const activityCode = url.searchParams.get('activityCode')?.toUpperCase()

    let query = supabase
      .schema('competition')
      .from('spiritual_activities')
      .select('*')
      .eq('user_id', userId)
      .order('occurred_at', { ascending: false })
      .limit(limit + 1)

    if (before) query = query.lt('occurred_at', before)
    if (activityCode) query = query.eq('activity_code', activityCode)

    const { data, error } = await query
    throwDatabaseError(error, 'Unable to load activities.')

    const hasMore = data.length > limit
    const items = hasMore ? data.slice(0, limit) : data

    return ok(items, {}, {
      limit,
      hasMore,
      nextCursor: hasMore ? items.at(-1)?.occurred_at ?? null : null,
    })
  } catch (error) {
    return errorResponse(error, request)
  }
}

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request)
    const idempotencyKey = request.headers.get('idempotency-key')?.trim()

    if (!idempotencyKey || idempotencyKey.length > 150) {
      throw ApiError.badRequest('A valid Idempotency-Key header is required.')
    }

    const input = recordActivitySchema.parse(await readJson(request))
    const { data, error } = await supabase.schema('api').rpc('record_spiritual_activity', {
      p_activity_code: input.activityCode,
      p_occurred_at: input.occurredAt,
      p_completed_at: input.completedAt ?? null,
      p_duration_seconds: input.durationSeconds ?? null,
      p_quantity: input.quantity,
      p_city_id: input.cityId ?? null,
      p_country_code: input.countryCode ?? null,
      p_idempotency_key: idempotencyKey,
      p_metadata: input.metadata as Json,
    })

    throwDatabaseError(error, 'Unable to record the activity.')
    const replayed = Boolean((data as Record<string, unknown> | null)?.replayed)
    return replayed ? ok(data) : created(data)
  } catch (error) {
    return errorResponse(error, request)
  }
}
