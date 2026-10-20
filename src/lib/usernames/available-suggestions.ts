import type { SupabaseClient } from '@supabase/supabase-js';

import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import type { Database } from '@/lib/supabase/types';
import { generateUsernameCandidates } from '@/lib/usernames/suggestions';

const AVAILABLE_USERNAME_COUNT = 5;

type AvailableUsernameSuggestionOptions = {
  username?: string;
  databaseErrorMessage?: string;
};

export async function getAvailableUsernameSuggestions(
  supabase: SupabaseClient<Database>,
  {
    username,
    databaseErrorMessage = 'Unable to generate username suggestions.',
  }: AvailableUsernameSuggestionOptions = {},
) {
  const generated = generateUsernameCandidates();
  const candidates = username ? [username, ...generated] : generated;
  const { data, error } = await supabase
    .schema('api')
    .rpc('check_username_availability', { p_usernames: candidates });

  throwDatabaseError(error, databaseErrorMessage);

  const availability = new Map(
    (data ?? []).map((entry) => [
      entry.username.toLowerCase(),
      entry.is_available,
    ]),
  );
  const suggestions = generated
    .filter((candidate) => availability.get(candidate.toLowerCase()))
    .slice(0, AVAILABLE_USERNAME_COUNT);

  if (suggestions.length < AVAILABLE_USERNAME_COUNT) {
    throw new ApiError(
      500,
      'USERNAME_SUGGESTIONS_UNAVAILABLE',
      'Unable to generate enough available username suggestions.',
    );
  }

  return { availability, suggestions };
}
