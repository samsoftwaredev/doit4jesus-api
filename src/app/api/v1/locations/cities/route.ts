import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { citySearchQuerySchema } from '@/lib/schemas/locations';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = citySearchQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase.schema('api').rpc('search_cities', {
      p_country_code: query.countryCode,
      p_query: query.q,
      p_limit: query.limit + 1,
      p_offset: query.offset,
    });

    throwDatabaseError(error, 'Unable to search cities.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit).map((city) => ({
        id: city.id,
        name: city.name,
        regionName: city.region_name,
        countryCode: city.country_code,
        timezone: city.timezone,
        latitude: city.latitude,
        longitude: city.longitude,
      })),
      { headers: { 'Cache-Control': 'private, max-age=86400' } },
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
