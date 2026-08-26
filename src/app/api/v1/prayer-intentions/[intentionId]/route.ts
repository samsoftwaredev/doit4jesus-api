import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { prayerIntentionIdSchema } from '@/lib/schemas/prayer-intention';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ intentionId: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const intentionId = prayerIntentionIdSchema.parse(
      (await context.params).intentionId,
    );
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('prayer')
      .from('prayer_intention_cards')
      .select('*')
      .eq('id', intentionId)
      .maybeSingle();

    throwDatabaseError(error, 'Unable to load the prayer intention.');
    if (!data) throw ApiError.notFound('The prayer intention was not found.');

    return ok({
      id: data.id,
      title: data.title,
      description: data.description,
      symbol: data.symbol,
      approvedAt: data.approved_at,
      expiresAt: data.expires_at,
      createdAt: data.created_at,
      prayerCount: data.prayer_count,
      creator: {
        displayName: data.creator_display_name,
        avatarUrl: data.creator_avatar_url,
        countryCode: data.creator_country_code,
      },
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
