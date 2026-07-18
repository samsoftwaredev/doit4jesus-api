import { ApiError } from '@/lib/api/errors'

export async function readJson(request: Request): Promise<unknown> {
  const contentType = request.headers.get('content-type') ?? ''

  if (!contentType.includes('application/json')) {
    throw ApiError.badRequest('Content-Type must be application/json.')
  }

  try {
    return await request.json()
  } catch {
    throw ApiError.badRequest('Request body must contain valid JSON.')
  }
}

export function parsePositiveInt(value: string | null, fallback: number, max: number) {
  if (value === null) return fallback
  const parsed = Number(value)
  if (!Number.isInteger(parsed) || parsed < 1) {
    throw ApiError.badRequest('Pagination values must be positive integers.')
  }
  return Math.min(parsed, max)
}
