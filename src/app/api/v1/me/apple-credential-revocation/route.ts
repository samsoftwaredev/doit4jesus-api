import { ApiError } from '@/lib/api/errors';
import { errorResponse, noContent } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { appleCredentialRevocationSchema } from '@/lib/schemas/apple-auth';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    await requireUser(request);
    const input = appleCredentialRevocationSchema.parse(
      await readJson(request),
    );
    const clientId = process.env.APPLE_CLIENT_ID;
    const clientSecret = process.env.APPLE_CLIENT_SECRET;
    if (!clientId || !clientSecret) {
      throw new ApiError(
        503,
        'APPLE_REVOCATION_UNAVAILABLE',
        'Apple credential revocation is not configured.',
      );
    }

    const tokenResponse = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code: input.authorizationCode,
        grant_type: 'authorization_code',
      }),
      cache: 'no-store',
    });
    const tokenPayload = (await tokenResponse.json()) as {
      access_token?: string;
      refresh_token?: string;
    };
    const token = tokenPayload.refresh_token ?? tokenPayload.access_token;
    if (!tokenResponse.ok || !token) {
      throw new ApiError(
        502,
        'APPLE_REVOCATION_FAILED',
        'Apple did not exchange the authorization code.',
      );
    }

    const revokeResponse = await fetch(
      'https://appleid.apple.com/auth/revoke',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          token,
          token_type_hint: tokenPayload.refresh_token
            ? 'refresh_token'
            : 'access_token',
        }),
        cache: 'no-store',
      },
    );
    if (!revokeResponse.ok) {
      throw new ApiError(
        502,
        'APPLE_REVOCATION_FAILED',
        'Apple did not revoke the credential.',
      );
    }
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
