import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { postalCodeSchema } from '@/lib/schemas/locations';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ postalCode: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const { postalCode: rawPostalCode } = await context.params;
    const postalCode = postalCodeSchema.parse(rawPostalCode);
    const { supabase } = await requireUser(request);
    const [postalResult, citiesResult, dioceseLinksResult] = await Promise.all([
      supabase
        .schema('app')
        .from('postal_codes')
        .select('*')
        .eq('postal_code', postalCode)
        .maybeSingle(),
      supabase
        .schema('app')
        .from('postal_code_cities')
        .select(
          'city_name, city_label, region_code, overlap_percent, city_status, is_primary',
        )
        .eq('postal_code', postalCode)
        .order('is_primary', { ascending: false })
        .order('overlap_percent', { ascending: false }),
      supabase
        .schema('app')
        .from('postal_code_dioceses')
        .select('diocese_id, label, match_status')
        .eq('postal_code', postalCode)
        .order('label'),
    ]);

    throwDatabaseError(postalResult.error, 'Unable to load the postal code.');
    throwDatabaseError(
      citiesResult.error,
      'Unable to load postal-code cities.',
    );
    throwDatabaseError(
      dioceseLinksResult.error,
      'Unable to load postal-code dioceses.',
    );
    if (!postalResult.data)
      throw ApiError.notFound('The postal code is not supported.');

    const dioceseIds = (dioceseLinksResult.data ?? [])
      .map((item) => item.diocese_id)
      .filter((id): id is string => Boolean(id));
    const { data: dioceses, error: diocesesError } = dioceseIds.length
      ? await supabase
          .schema('app')
          .from('dioceses')
          .select('id, name')
          .in('id', dioceseIds)
      : { data: [], error: null };
    throwDatabaseError(diocesesError, 'Unable to load dioceses.');
    const diocesesById = new Map(
      (dioceses ?? []).map((item) => [item.id, item.name]),
    );

    const postal = postalResult.data;
    return ok(
      {
        postalCode: postal.postal_code,
        primaryCity: postal.primary_city,
        regionCodes: postal.region_codes,
        latitude: postal.latitude,
        longitude: postal.longitude,
        timezone: postal.timezone,
        dioceseStatus: postal.diocese_status,
        cities: (citiesResult.data ?? []).map((city) => ({
          name: city.city_name,
          label: city.city_label,
          regionCode: city.region_code,
          overlapPercent: city.overlap_percent,
          status: city.city_status,
          isPrimary: city.is_primary,
        })),
        dioceses: (dioceseLinksResult.data ?? []).map((link) => ({
          id: link.diocese_id,
          name: link.diocese_id
            ? (diocesesById.get(link.diocese_id) ?? link.label)
            : link.label,
          matchStatus: link.match_status,
        })),
      },
      { headers: { 'Cache-Control': 'private, max-age=86400' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
