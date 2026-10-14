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
    const preview = (data ?? {}) as {
      recordCount?: number;
      [key: string]: unknown;
    };
    const recordCount = preview.recordCount ?? 0;
    const hasMore = query.offset + query.limit < recordCount;

    return ok(
      preview,
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
