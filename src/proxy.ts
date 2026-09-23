import { NextRequest, NextResponse } from 'next/server';

const LOCALHOST_ORIGIN = /^http:\/\/localhost(:\d+)?$/;
const ALLOWED_HEADERS = 'Content-Type, Authorization, Idempotency-Key';

export function proxy(request: NextRequest) {
  const origin = request.headers.get('origin') ?? '';
  const isLocalhostOrigin = LOCALHOST_ORIGIN.test(origin);

  // Handle preflight requests
  if (request.method === 'OPTIONS') {
    const response = new NextResponse(null, { status: 204 });
    if (isLocalhostOrigin) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Vary', 'Origin');
    }
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    );
    response.headers.set('Access-Control-Allow-Headers', ALLOWED_HEADERS);
    response.headers.set('Access-Control-Max-Age', '86400');
    return response;
  }

  const response = NextResponse.next();

  if (isLocalhostOrigin) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Vary', 'Origin');
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    );
    response.headers.set('Access-Control-Allow-Headers', ALLOWED_HEADERS);
  }

  return response;
}

export const config = {
  matcher: '/api/:path*',
};
