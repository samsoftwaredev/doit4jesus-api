import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  reportIdSchema,
  resolveSafetyReportSchema,
} from '@/lib/schemas/community-safety';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ reportId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const reportId = reportIdSchema.parse((await context.params).reportId);
    const input = resolveSafetyReportSchema.parse(await readJson(request));
    const { supabase, userId } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('app')
      .from('content_reports')
      .update({
        status: input.status,
        admin_notes: input.adminNotes ?? null,
        reviewed_by: userId,
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', reportId)
      .select('*')
      .single();
    throwDatabaseError(error, 'Unable to resolve the safety report.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
