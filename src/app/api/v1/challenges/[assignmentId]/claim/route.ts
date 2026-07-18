import { errorResponse, ok } from '@/lib/api/response'
import { throwDatabaseError } from '@/lib/api/database'
import { requireUser } from '@/lib/auth/require-user'

export const dynamic = 'force-dynamic'

type Context = { params: Promise<{ assignmentId: string }> }

export async function POST(request: Request, context: Context) {
  try {
    const { assignmentId } = await context.params
    const { supabase } = await requireUser(request)
    const { data, error } = await supabase.schema('api').rpc('claim_challenge_reward', {
      p_assignment_id: assignmentId,
    })

    throwDatabaseError(error, 'Unable to claim the challenge reward.')
    return ok(data)
  } catch (error) {
    return errorResponse(error, request)
  }
}
