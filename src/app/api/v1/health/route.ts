import { ok } from '@/lib/api/response'

export const dynamic = 'force-dynamic'

export async function GET() {
  return ok({
    status: 'ok',
    service: 'holy-competition-api',
    timestamp: new Date().toISOString(),
  })
}
