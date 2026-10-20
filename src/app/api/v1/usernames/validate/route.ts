import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { usernameValidationQuerySchema } from '@/lib/schemas/username';
import { getAvailableUsernameSuggestions } from '@/lib/usernames/available-suggestions';
import { evaluateUsername } from '@/lib/usernames/moderation';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = usernameValidationQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const username = query.username.trim();
    const moderation = evaluateUsername(username);
    const { availability, suggestions } = await getAvailableUsernameSuggestions(
      supabase,
      {
        username: moderation.valid ? username : undefined,
        databaseErrorMessage: 'Unable to validate the username.',
      },
    );

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
