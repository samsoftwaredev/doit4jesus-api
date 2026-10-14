import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  createEmailTestRecipientSchema,
  emailTestRecipientQuerySchema,
} from '@/lib/schemas/email';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const query = emailTestRecipientQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('app')
      .from('email_test_recipients')
      .select('id, email, created_at')
      .order('email')
      .range(query.offset, query.offset + query.limit);
    throwDatabaseError(error, 'Unable to load test recipients.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    return ok(
      rows.slice(0, query.limit).map((row) => ({
        id: row.id,
        email: row.email,
        createdAt: row.created_at,
      })),
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

export async function POST(request: Request) {
  try {
    const input = createEmailTestRecipientSchema.parse(await readJson(request));
    const { supabase, userId } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('app')
      .from('email_test_recipients')
      .insert({ email: input.email, created_by: userId })
      .select('id, email, created_at')
      .single();
    throwDatabaseError(error, 'Unable to add the test recipient.');
    return created({
      id: data.id,
      email: data.email,
      createdAt: data.created_at,
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
