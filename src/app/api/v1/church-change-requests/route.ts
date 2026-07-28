import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import {
  churchChangeRequestQuerySchema,
  createChurchChangeRequestSchema,
} from '@/lib/schemas/church';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const url = new URL(request.url);
    const query = churchChangeRequestQuerySchema.parse(
      Object.fromEntries(url.searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('app')
      .from('church_change_requests')
      .select('*')
      .eq('submitted_by', userId)
      .order('created_at', { ascending: false })
      .range(query.offset, query.offset + query.limit);

    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);

    const { data, error } = await dbQuery;
    throwDatabaseError(error, 'Unable to load church change requests.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;

    return ok(
      rows.slice(0, query.limit),
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
    const input = createChurchChangeRequestSchema.parse(
      await readJson(request),
    );
    const proposedServiceTimes = input.serviceTimes.map((serviceTime) => ({
      service_type: serviceTime.serviceType,
      weekday: [
        'sunday',
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
      ].indexOf(serviceTime.weekday),
      start_time: serviceTime.startTime,
      end_time: serviceTime.endTime ?? null,
    }));
    const proposedChurch =
      input.requestType === 'createChurch'
        ? {
            diocese_id: input.church.dioceseId ?? null,
            name: input.church.name,
            address_line_1: input.church.addressLine1,
            address_line_2: input.church.addressLine2 ?? null,
            city: input.church.city,
            region_name: input.church.regionName ?? null,
            postal_code: input.church.postalCode ?? null,
            country_code: input.church.countryCode,
            timezone: input.church.timezone,
            latitude: input.church.latitude,
            longitude: input.church.longitude,
          }
        : {};
    const { data, error } = await supabase
      .schema('app')
      .from('church_change_requests')
      .insert({
        submitted_by: userId,
        request_type:
          input.requestType === 'createChurch'
            ? 'create_church'
            : 'schedule_update',
        church_id:
          input.requestType === 'scheduleUpdate' ? input.churchId : null,
        proposed_church: proposedChurch,
        proposed_service_times: proposedServiceTimes,
        notes: input.notes ?? null,
      })
      .select('*')
      .single();

    throwDatabaseError(error, 'Unable to submit the church change request.');
    return created(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
