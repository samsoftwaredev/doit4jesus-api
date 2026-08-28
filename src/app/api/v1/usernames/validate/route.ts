import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { usernameValidationQuerySchema } from '@/lib/schemas/username';
import { evaluateUsername } from '@/lib/usernames/moderation';
import { generateUsernameCandidates } from '@/lib/usernames/suggestions';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = usernameValidationQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const username = query.username.trim();
    const moderation = evaluateUsername(username);
    const generated = generateUsernameCandidates();
    const candidates = moderation.valid ? [username, ...generated] : generated;

    const { data, error } = await supabase
      .schema('api')
      .rpc('check_username_availability', { p_usernames: candidates });

    throwDatabaseError(error, 'Unable to validate the username.');

    const availability = new Map(
      (data ?? []).map((entry) => [
        entry.username.toLowerCase(),
        entry.is_available,
      ]),
    );
    const suggestions = generated
      .filter((candidate) => availability.get(candidate.toLowerCase()))
      .slice(0, 5);

    if (suggestions.length < 5) {
      throw new ApiError(
        500,
        'USERNAME_SUGGESTIONS_UNAVAILABLE',
        'Unable to generate enough available username suggestions.',
      );
    }

    const available =
      moderation.valid && availability.get(username.toLowerCase()) === true;
    const reason = !moderation.valid
      ? moderation.reason
      : available
        ? null
        : 'USERNAME_TAKEN';

    return ok(
      {
        username,
        normalizedUsername: username.toLowerCase(),
        valid: moderation.valid,
        available,
        reason,
        suggestions,
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
