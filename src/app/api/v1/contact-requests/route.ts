import { throwDatabaseError } from '@/lib/api/database'
import { created, errorResponse } from '@/lib/api/response'
import { readJson } from '@/lib/api/validation'
import { createContactRequestSchema } from '@/lib/schemas/contact'
import { createAdminClient } from '@/lib/supabase/admin'

export const dynamic = 'force-dynamic'

/**
 * This route is intentionally unauthenticated so people who cannot sign in can
 * still contact support. The service-role client stays server-side and is only
 * used after the request has passed strict validation.
 */
export async function POST(request: Request) {
  try {
    const input = createContactRequestSchema.parse(await readJson(request))
    const supabase = createAdminClient()
    const { data, error } = await supabase
      .schema('app')
      .from('contact_requests')
      .insert({
        name: input.name,
        email: input.email,
        subject: input.subject,
        other_subject: input.otherSubject ?? null,
        message: input.message,
      })
      .select('id, created_at')
      .single()

    throwDatabaseError(error, 'Unable to submit the contact request.')
    return created({ id: data.id, createdAt: data.created_at })
  } catch (error) {
    return errorResponse(error, request)
  }
}
