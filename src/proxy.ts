import { NextRequest, NextResponse } from 'next/server';

import { updateSession } from '@/lib/supabase/proxy';

const LOCALHOST_ORIGIN = /^http:\/\/localhost(:\d+)?$/;
const ALLOWED_HEADERS = 'Content-Type, Authorization, Idempotency-Key';

export async function proxy(request: NextRequest) {
  const origin = request.headers.get('origin') ?? '';
  const isLocalhostOrigin = LOCALHOST_ORIGIN.test(origin);
  const isApiRequest = request.nextUrl.pathname.startsWith('/api/');

  // Handle preflight requests
  if (isApiRequest && request.method === 'OPTIONS') {
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

  const response = await updateSession(request);

  if (isApiRequest && isLocalhostOrigin) {
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
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
