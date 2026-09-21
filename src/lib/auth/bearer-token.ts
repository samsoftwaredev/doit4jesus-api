import { ApiError } from '@/lib/api/errors';

export function readBearerToken(request: Request) {
  const authorization = request.headers.get('authorization');
  if (!authorization) return null;

  const [scheme, token] = authorization.split(' ', 2);
  if (scheme?.toLowerCase() !== 'bearer' || !token) {
    throw ApiError.unauthorized('Authorization must use the Bearer scheme.');
  }

  return token;
}
