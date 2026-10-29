import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  accountUserIdSchema,
  adminUserDeletionPreviewQuerySchema,
} from '@/lib/schemas/users';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ userId: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const userId = accountUserIdSchema.parse((await context.params).userId);
    const query = adminUserDeletionPreviewQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_admin_user_deletion_preview', {
        p_user_id: userId,
        p_section: query.section,
        p_limit: query.limit,
        p_offset: query.offset,
      });

    throwDatabaseError(error, 'Unable to load the account deletion preview.');
    const { data: legalAcceptances, error: legalAcceptanceError } =
      await supabase
        .schema('api')
        .rpc('get_admin_user_legal_acceptances', { p_user_id: userId });
    throwDatabaseError(
      legalAcceptanceError,
      'Unable to load legal acceptance records.',
    );
    const [blocksResult, reportsResult] = await Promise.all([
      supabase
        .schema('app')
        .from('user_blocks')
        .select('*')
        .or(`blocker_id.eq.${userId},blocked_user_id.eq.${userId}`),
      supabase
        .schema('app')
        .from('content_reports')
        .select('*')
        .or(`reporter_id.eq.${userId},target_owner_id.eq.${userId}`),
    ]);
    throwDatabaseError(blocksResult.error, 'Unable to load block records.');
    throwDatabaseError(reportsResult.error, 'Unable to load safety reports.');
    const preview = (data ?? {}) as {
      recordCount?: number;
      [key: string]: unknown;
    };
    const recordCount = preview.recordCount ?? 0;
    const hasMore = query.offset + query.limit < recordCount;

    return ok(
      {
        ...preview,
        legalAcceptances: legalAcceptances ?? [],
        userBlocks: blocksResult.data ?? [],
        safetyReports: reportsResult.data ?? [],
      },
      { headers: { 'Cache-Control': 'no-store' } },
      {
        limit: query.limit,
        offset: query.offset,
        hasMore,
        nextOffset: hasMore ? query.offset + query.limit : null,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
