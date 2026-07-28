import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { createUserChurchLinkSchema } from '@/lib/schemas/church';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const { data: links, error: linksError } = await supabase
      .schema('app')
      .from('user_churches')
      .select('church_id, is_primary, linked_at')
      .eq('user_id', userId)
      .order('is_primary', { ascending: false })
      .order('linked_at');

    throwDatabaseError(linksError, 'Unable to load linked churches.');
    const churchIds = (links ?? []).map((link) => link.church_id);
    const { data: churches, error: churchesError } = churchIds.length
      ? await supabase
          .schema('app')
          .from('churches')
          .select(
            'id, name, city, region_name, country_code, timezone, latitude, longitude, is_active',
          )
          .in('id', churchIds)
      : { data: [], error: null };

    throwDatabaseError(churchesError, 'Unable to load linked church details.');
    const churchesById = new Map(
      (churches ?? []).map((church) => [church.id, church]),
    );

    return ok(
      (links ?? [])
        .map((link) => {
          const church = churchesById.get(link.church_id);
          if (!church) return null;

          return {
            church: {
              id: church.id,
              name: church.name,
              city: church.city,
              regionName: church.region_name,
              countryCode: church.country_code,
              timezone: church.timezone,
              latitude: church.latitude,
              longitude: church.longitude,
              isActive: church.is_active,
            },
            isPrimary: link.is_primary,
            linkedAt: link.linked_at,
          };
        })
        .filter((item): item is NonNullable<typeof item> => item !== null),
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const input = createUserChurchLinkSchema.parse(await readJson(request));
    const { data, error } = await supabase
      .schema('api')
      .rpc('link_current_user_church', {
        p_church_id: input.churchId,
        p_is_primary: input.isPrimary,
      });

    throwDatabaseError(error, 'Unable to link the church.');
    const result = data as { created?: boolean };
    return result.created ? created(data) : ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
