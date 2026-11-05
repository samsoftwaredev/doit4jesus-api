import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, noContent, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { churchIdSchema, weekdayCodes } from '@/lib/schemas/church';
import { updateChurchSubscriptionSchema } from '@/lib/schemas/church-subscription';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ churchId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const { churchId: rawChurchId } = await context.params;
    const churchId = churchIdSchema.parse(rawChurchId);
    const input = updateChurchSubscriptionSchema.parse(await readJson(request));
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('update_church_subscription', {
        p_church_id: churchId,
        p_service_types: input.serviceTypes ?? null,
        p_notification_weekdays:
          input.notificationWeekdays?.map((day) => weekdayCodes.indexOf(day)) ??
          null,
      });
    throwDatabaseError(error, 'Unable to update the church subscription.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function DELETE(request: Request, context: Context) {
  try {
    const { churchId: rawChurchId } = await context.params;
    const churchId = churchIdSchema.parse(rawChurchId);
    const { supabase } = await requireUser(request);
    const { error } = await supabase
      .schema('api')
      .rpc('delete_church_subscription', { p_church_id: churchId });
    throwDatabaseError(error, 'Unable to delete the church subscription.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
