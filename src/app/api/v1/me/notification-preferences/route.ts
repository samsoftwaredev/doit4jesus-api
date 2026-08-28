import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { loadNotificationPreferences } from '@/lib/notifications/preferences';
import { updateNotificationPreferencesSchema } from '@/lib/schemas/notification-preferences';
import type { Database } from '@/lib/supabase/types';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    return ok(await loadNotificationPreferences(supabase, userId), {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function PATCH(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const input = updateNotificationPreferencesSchema.parse(
      await readJson(request),
    );
    const update: Database['app']['Tables']['notification_preferences']['Update'] =
      {};

    if (input.dailyRosaryReminder !== undefined) {
      update.daily_rosary_reminder = input.dailyRosaryReminder;
    }
    if (input.confessionReminder !== undefined) {
      update.confession_reminder = input.confessionReminder;
    }
    if (input.eucharisticAdoration !== undefined) {
      update.eucharistic_adoration = input.eucharisticAdoration;
    }

    const { error } = await supabase
      .schema('app')
      .from('notification_preferences')
      .upsert({ user_id: userId, ...update }, { onConflict: 'user_id' });

    throwDatabaseError(error, 'Unable to update notification preferences.');
    return ok(await loadNotificationPreferences(supabase, userId), {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
