import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { countrySearchQuerySchema } from '@/lib/schemas/locations';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = countrySearchQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('api')
      .rpc('search_countries', {
        p_query: query.q ?? null,
        p_limit: query.limit + 1,
        p_offset: query.offset,
      });

    throwDatabaseError(error, 'Unable to search countries.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit).map((country) => ({
        code: country.code,
        name: country.name,
        latitude: country.latitude,
        longitude: country.longitude,
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
