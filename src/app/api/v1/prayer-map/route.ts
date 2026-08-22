import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { prayerMapQuerySchema } from '@/lib/schemas/prayer-map';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const url = new URL(request.url);
    const query = prayerMapQuerySchema.parse(
      Object.fromEntries(url.searchParams.entries()),
    );

    let dbQuery = supabase
      .schema('prayer')
      .from('map_markers')
      .select('*')
      .eq('aggregation_level', query.level)
      .lte('period_start', query.from)
      .gte('period_end', query.to)
      .gte('unique_users', 5)
      .order('prayer_count', { ascending: false });

    if (query.countryCode)
      dbQuery = dbQuery.eq('country_code', query.countryCode);

    const { data, error } = await dbQuery;
    throwDatabaseError(error, 'Unable to load prayer-map markers.');

    return ok(
      data ?? [],
      {},
      {
        level: query.level,
        from: query.from,
        to: query.to,
        privacyThreshold: 5,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
