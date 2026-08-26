import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { created, errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import {
  prayerIntentionIdSchema,
  prayerIntentionPrayersQuerySchema,
} from '@/lib/schemas/prayer-intention';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ intentionId: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const intentionId = prayerIntentionIdSchema.parse(
      (await context.params).intentionId,
    );
    const query = prayerIntentionPrayersQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { supabase } = await requireUser(request);

    // RLS exposes this source record only to its creator or an administrator.
    // Looking it up first makes that authorization boundary explicit and keeps
    // non-owners from learning whether an intention exists.
    const { data: intention, error: intentionError } = await supabase
      .schema('prayer')
      .from('prayer_intentions')
      .select('id')
      .eq('id', intentionId)
      .maybeSingle();
    throwDatabaseError(intentionError, 'Unable to load the prayer intention.');
    if (!intention)
      throw ApiError.notFound('The prayer intention was not found.');

    const { data, error } = await supabase
      .schema('prayer')
      .from('prayer_intention_prayer_participants')
      .select('*')
      .eq('intention_id', intentionId)
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .range(query.offset, query.offset + query.limit);
    throwDatabaseError(error, 'Unable to load people who prayed.');

    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    return ok(
      rows.slice(0, query.limit).map((row) => ({
        id: row.id,
        user: {
          id: row.user_id,
          displayName: row.display_name,
          avatarUrl: row.avatar_url,
          countryCode: row.country_code,
        },
        prayedAt: row.created_at,
      })),
      {},
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

export async function POST(request: Request, context: Context) {
  try {
    const intentionId = prayerIntentionIdSchema.parse(
      (await context.params).intentionId,
    );
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('record_prayer_intention_prayer', { p_intention_id: intentionId });

    throwDatabaseError(error, 'Unable to record the prayer.');
    return created(
      data as {
        id: string;
        intentionId: string;
        prayedAt: string;
        prayerCount: number;
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
