import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { churchSearchQuerySchema } from '@/lib/schemas/church';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const url = new URL(request.url);
    const query = churchSearchQuerySchema.parse(
      Object.fromEntries(url.searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('api')
      .rpc('search_churches_v2', {
        p_country_code: query.countryCode ?? null,
        p_city: query.city ?? null,
        p_diocese: query.diocese ?? null,
        p_postal_code: query.postalCode ?? null,
        p_diocese_id: query.dioceseId ?? null,
        p_query: query.q ?? null,
        p_radius_miles: query.radiusMiles,
        p_limit: query.limit + 1,
        p_offset: query.offset,
      });

    throwDatabaseError(error, 'Unable to search churches.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    const items = hasMore ? rows.slice(0, query.limit) : rows;

    return ok(
      items.map((church) => ({
        id: church.id,
        name: church.name,
        address: {
          line1: church.address_line_1,
          line2: church.address_line_2,
          city: church.city,
          regionName: church.region_name,
          postalCode: church.postal_code,
          countryCode: church.country_code,
        },
        city: church.city,
        regionName: church.region_name,
        countryCode: church.country_code,
        dioceseId: church.diocese_id,
        dioceseName: church.diocese_name,
        timezone: church.timezone,
        latitude: church.latitude,
        longitude: church.longitude,
        distanceMiles: church.distance_miles,
        directoryVerificationStatus: church.directory_verification_status,
        scheduleStatus: church.schedule_status,
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
