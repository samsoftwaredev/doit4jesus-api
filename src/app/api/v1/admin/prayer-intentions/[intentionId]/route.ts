import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  prayerIntentionIdSchema,
  reviewPrayerIntentionSchema,
} from '@/lib/schemas/prayer-intention';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ intentionId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const intentionId = prayerIntentionIdSchema.parse(
      (await context.params).intentionId,
    );
    const input = reviewPrayerIntentionSchema.parse(await readJson(request));
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('review_prayer_intention', {
        p_intention_id: intentionId,
        p_decision: input.decision,
      });

    throwDatabaseError(error, 'Unable to review the prayer intention.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
