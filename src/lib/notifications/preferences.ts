import { throwDatabaseError } from '@/lib/api/database';
import type { AuthenticatedContext } from '@/lib/auth/require-user';

export const DEFAULT_NOTIFICATION_PREFERENCES = {
  dailyRosaryReminder: true,
  confessionReminder: true,
  eucharisticAdoration: true,
} as const;

export async function loadNotificationPreferences(
  supabase: AuthenticatedContext['supabase'],
  userId: string,
) {
  const { data, error } = await supabase
    .schema('app')
    .from('notification_preferences')
    .select('daily_rosary_reminder, confession_reminder, eucharistic_adoration')
    .eq('user_id', userId)
    .maybeSingle();

  throwDatabaseError(error, 'Unable to load notification preferences.');

  return data
    ? {
        dailyRosaryReminder: data.daily_rosary_reminder,
        confessionReminder: data.confession_reminder,
        eucharisticAdoration: data.eucharistic_adoration,
      }
    : { ...DEFAULT_NOTIFICATION_PREFERENCES };
}
