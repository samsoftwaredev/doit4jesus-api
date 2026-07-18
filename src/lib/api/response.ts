import { ZodError } from 'zod'
import { ApiError } from '@/lib/api/errors'

export type ApiMeta = Record<string, unknown>

export function ok<T>(data: T, init: ResponseInit = {}, meta?: ApiMeta) {
  return Response.json(meta ? { data, meta } : { data }, { status: 200, ...init })
}

export function created<T>(data: T, init: ResponseInit = {}) {
  return Response.json({ data }, { status: 201, ...init })
}

export function noContent() {
  return new Response(null, { status: 204 })
}

export function requestId(request: Request) {
  return request.headers.get('x-request-id') ?? crypto.randomUUID()
}

export function errorResponse(error: unknown, request: Request) {
  const id = requestId(request)

  if (error instanceof ApiError) {
    return Response.json(
      {
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
          requestId: id,
        },
      },
      { status: error.status, headers: { 'x-request-id': id } },
    )
  }

  if (error instanceof ZodError) {
    return Response.json(
      {
        error: {
          code: 'VALIDATION_ERROR',
          message: 'The request payload is invalid.',
          details: error.flatten(),
          requestId: id,
        },
      },
      { status: 422, headers: { 'x-request-id': id } },
    )
  }

  console.error('Unhandled API error', { requestId: id, error })

  return Response.json(
    {
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred.',
        requestId: id,
      },
    },
    { status: 500, headers: { 'x-request-id': id } },
  )
}
