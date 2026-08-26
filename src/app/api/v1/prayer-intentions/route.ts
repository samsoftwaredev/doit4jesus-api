import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import {
  createPrayerIntentionSchema,
  prayerIntentionFeedQuerySchema,
} from '@/lib/schemas/prayer-intention';

export const dynamic = 'force-dynamic';

function toCard(row: {
  id: string;
  title: string;
  description: string;
  symbol: string | null;
  approved_at: string;
  expires_at: string;
  created_at: string;
  creator_display_name: string;
  creator_avatar_url: string | null;
  creator_country_code: string | null;
  prayer_count: number;
}) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    symbol: row.symbol,
    approvedAt: row.approved_at,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    prayerCount: row.prayer_count,
    creator: {
      displayName: row.creator_display_name,
      avatarUrl: row.creator_avatar_url,
      countryCode: row.creator_country_code,
    },
  };
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = prayerIntentionFeedQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('prayer')
      .from('prayer_intention_cards')
      .select('*')
      .order('approved_at', { ascending: false })
      .order('id', { ascending: false })
      .range(query.offset, query.offset + query.limit);

    throwDatabaseError(error, 'Unable to load prayer intentions.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit).map(toCard),
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

export async function POST(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const input = createPrayerIntentionSchema.parse(await readJson(request));
    const { data, error } = await supabase
      .schema('prayer')
      .from('prayer_intentions')
      .insert({
        creator_id: userId,
        title: input.title,
        description: input.description,
        symbol: input.symbol ?? null,
      })
      .select('*')
      .single();

    throwDatabaseError(error, 'Unable to submit the prayer intention.');
    return created({
      id: data.id,
      title: data.title,
      description: data.description,
      symbol: data.symbol,
      status: data.status,
      createdAt: data.created_at,
      reviewedAt: data.reviewed_at,
      expiresAt: data.expires_at,
      prayerCount: 0,
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
