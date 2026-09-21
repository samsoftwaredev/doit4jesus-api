import type { SupabaseClient } from '@supabase/supabase-js';

import { ApiError } from '@/lib/api/errors';
import { readBearerToken } from '@/lib/auth/bearer-token';
import { createBearerClient } from '@/lib/supabase/bearer';
import { createPublicClient } from '@/lib/supabase/public';
import { createClient } from '@/lib/supabase/server';
import type { Database } from '@/lib/supabase/types';

export type OptionalUserContext = {
  supabase: SupabaseClient<Database>;
  userId: string | null;
  claims: Record<string, unknown>;
  authMode: 'anonymous' | 'bearer' | 'cookie';
};

export async function getOptionalUser(
  request: Request,
): Promise<OptionalUserContext> {
  const accessToken = readBearerToken(request);

  if (accessToken) {
    const supabase = createBearerClient(accessToken);
    const { data, error } = await supabase.auth.getClaims(accessToken);
    const claims = data?.claims as Record<string, unknown> | undefined;
    const userId = typeof claims?.sub === 'string' ? claims.sub : null;

    if (error || !userId) throw ApiError.unauthorized();

    return {
      supabase,
      userId,
      claims: claims ?? {},
      authMode: 'bearer',
    };
  }

  const cookieClient = await createClient();
  const { data, error } = await cookieClient.auth.getClaims();
  const claims = data?.claims as Record<string, unknown> | undefined;
  const userId = typeof claims?.sub === 'string' ? claims.sub : null;

  if (!error && userId) {
    return {
      supabase: cookieClient,
      userId,
      claims: claims ?? {},
      authMode: 'cookie',
    };
  }

  return {
    supabase: createPublicClient(),
    userId: null,
    claims: {},
    authMode: 'anonymous',
  };
}
