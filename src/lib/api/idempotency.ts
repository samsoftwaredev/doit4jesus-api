import { ApiError } from '@/lib/api/errors';

export function requireIdempotencyKey(request: Request) {
  const idempotencyKey = request.headers.get('idempotency-key')?.trim();

  if (!idempotencyKey || idempotencyKey.length > 150) {
    throw ApiError.badRequest('A valid Idempotency-Key header is required.');
  }

  return idempotencyKey;
}
