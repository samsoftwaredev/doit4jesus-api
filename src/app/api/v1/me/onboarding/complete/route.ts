import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { loadNotificationPreferences } from '@/lib/notifications/preferences';
import { loadCurrentProfile } from '@/lib/profiles/current-profile';
import { completeProfileSetupSchema } from '@/lib/schemas/onboarding';
import { assertUsernameAllowed } from '@/lib/usernames/moderation';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const input = completeProfileSetupSchema.parse(await readJson(request));

    if (input.username !== null) assertUsernameAllowed(input.username);

    const { error } = await supabase
      .schema('api')
      .rpc('complete_current_user_profile_setup', {
        p_display_name: input.displayName,
        p_username: input.username,
        p_gender: input.gender,
        p_country_code: input.countryCode,
        p_city_id: input.cityId,
        p_daily_rosary_reminder:
          input.notificationPreferences.dailyRosaryReminder,
        p_confession_reminder: input.notificationPreferences.confessionReminder,
        p_eucharistic_adoration:
          input.notificationPreferences.eucharisticAdoration,
      });

    throwDatabaseError(error, 'Unable to complete profile setup.');
    const [profile, notificationPreferences] = await Promise.all([
      loadCurrentProfile(supabase, userId),
      loadNotificationPreferences(supabase, userId),
    ]);

    return ok(
      { profile, notificationPreferences },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
