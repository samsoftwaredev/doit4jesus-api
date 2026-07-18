import { errorResponse, ok } from '@/lib/api/response'
import { parsePositiveInt } from '@/lib/api/validation'
import { throwDatabaseError } from '@/lib/api/database'
import { requireUser } from '@/lib/auth/require-user'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request)
    const url = new URL(request.url)
    const limit = parsePositiveInt(url.searchParams.get('limit'), 20, 100)
    const unreadOnly = url.searchParams.get('unreadOnly') === 'true'

    let query = supabase
      .schema('app')
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(limit)

    if (unreadOnly) query = query.is('read_at', null)

    const { data, error } = await query
    throwDatabaseError(error, 'Unable to load notifications.')
    return ok(data ?? [])
  } catch (error) {
    return errorResponse(error, request)
  }
}
