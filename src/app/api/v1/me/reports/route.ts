import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { createSafetyReportSchema } from '@/lib/schemas/community-safety';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const input = createSafetyReportSchema.parse(await readJson(request));
    const targetColumns = {
      target_user_id: input.targetType === 'user' ? input.targetId : null,
      prayer_intention_id:
        input.targetType === 'prayer_intention' ? input.targetId : null,
      event_id: input.targetType === 'event' ? input.targetId : null,
    };
    const { data, error } = await supabase
      .schema('app')
      .from('content_reports')
      .insert({
        reporter_id: userId,
        target_type: input.targetType,
        reason: input.reason,
        details: input.details ?? null,
        ...targetColumns,
      })
      .select('id,status,created_at')
      .single();

    throwDatabaseError(error, 'Unable to submit the report.');
    return created({
      id: data.id,
      status: data.status,
      createdAt: data.created_at,
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
