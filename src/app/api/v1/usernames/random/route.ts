import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { getAvailableUsernameSuggestions } from '@/lib/usernames/available-suggestions';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const { suggestions } = await getAvailableUsernameSuggestions(supabase);

    return ok(
      { usernames: suggestions },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
