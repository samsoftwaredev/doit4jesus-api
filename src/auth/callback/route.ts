import { type NextRequest, NextResponse } from 'next/server';

import { createClient } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const requestedNext = url.searchParams.get('next') ?? '/';
  const requestedNextUrl = new URL(requestedNext, url.origin);
  const next =
    requestedNext.startsWith('/') && requestedNextUrl.origin === url.origin
      ? `${requestedNextUrl.pathname}${requestedNextUrl.search}${requestedNextUrl.hash}`
      : '/';

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(new URL(next, url.origin));
    }
  }

  return NextResponse.redirect(new URL('/auth/error', url.origin));
}
