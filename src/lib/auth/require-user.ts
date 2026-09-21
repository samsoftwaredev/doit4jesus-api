import type { SupabaseClient } from '@supabase/supabase-js';

import { ApiError } from '@/lib/api/errors';
import { readBearerToken } from '@/lib/auth/bearer-token';
import { createBearerClient } from '@/lib/supabase/bearer';
import { createClient } from '@/lib/supabase/server';
import type { Database } from '@/lib/supabase/types';

export type AuthenticatedContext = {
  supabase: SupabaseClient<Database>;
  userId: string;
  claims: Record<string, unknown>;
  authMode: 'cookie' | 'bearer';
};

export async function requireUser(
  request: Request,
): Promise<AuthenticatedContext> {
  const accessToken = readBearerToken(request);
  const supabase = accessToken
    ? createBearerClient(accessToken)
    : await createClient();
  const { data, error } = accessToken
    ? await supabase.auth.getClaims(accessToken)
    : await supabase.auth.getClaims();

  const claims = data?.claims as Record<string, unknown> | undefined;
  const userId = typeof claims?.sub === 'string' ? claims.sub : null;

  if (error || !userId) {
    throw ApiError.unauthorized();
  }

  return {
    supabase,
    userId,
    claims: claims ?? {},
    authMode: accessToken ? 'bearer' : 'cookie',
  };
}
