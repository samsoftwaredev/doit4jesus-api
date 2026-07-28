import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, noContent, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { churchIdSchema, setPrimaryChurchSchema } from '@/lib/schemas/church';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ churchId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const { churchId: rawChurchId } = await context.params;
    const churchId = churchIdSchema.parse(rawChurchId);
    const input = setPrimaryChurchSchema.parse(await readJson(request));
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('set_current_user_primary_church', {
        p_church_id: churchId,
      });

    throwDatabaseError(error, 'Unable to update the primary church.');
    return ok({ ...((data as object) ?? {}), isPrimary: input.isPrimary });
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
      .rpc('unlink_current_user_church', {
        p_church_id: churchId,
      });

    throwDatabaseError(error, 'Unable to unlink the church.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
