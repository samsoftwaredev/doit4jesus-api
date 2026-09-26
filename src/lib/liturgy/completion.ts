import { throwDatabaseError } from '@/lib/api/database';
import type { AuthenticatedContext } from '@/lib/auth/require-user';

export async function loadDailyScriptureCompletion(
  supabase: AuthenticatedContext['supabase'],
  readingDate: string,
) {
  const { data, error } = await supabase
    .schema('api')
    .rpc('get_my_daily_scripture_completion', {
      p_reading_date: readingDate,
    });
  throwDatabaseError(error, 'Unable to load Daily Scripture completion.');
  return data;
}
