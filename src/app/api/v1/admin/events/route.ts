import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { toEventResponse } from '@/lib/events/presentation';
import {
  adminEventsQuerySchema,
  createEventSchema,
} from '@/lib/schemas/events';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const query = adminEventsQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('app')
      .from('admin_event_summaries')
      .select('*')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false });

    if (query.status !== 'all') dbQuery = dbQuery.eq('status', query.status);
    const { data, error } = await dbQuery.range(
      query.offset,
      query.offset + query.limit,
    );
    throwDatabaseError(error, 'Unable to load events.');

    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    return ok(
      rows.slice(0, query.limit).map((row) => toEventResponse(row, true)),
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
    const { supabase, userId } = await requireAdmin(request);
    const input = createEventSchema.parse(await readJson(request));
    const isOnline = input.eventType === 'online';
    const reviewedAt = new Date().toISOString();
    const { data, error } = await supabase
      .schema('app')
      .from('events')
      .insert({
        creator_id: userId,
        title: input.title,
        description: input.description,
        image_url: input.imageUrl ?? null,
        event_url: input.eventUrl ?? null,
        event_type: input.eventType,
        online_url: isOnline ? input.onlineUrl : null,
        location_name: isOnline ? null : input.locationName,
        address_line_1: isOnline ? null : input.addressLine1,
        address_line_2: isOnline ? null : (input.addressLine2 ?? null),
        city: isOnline ? null : input.city,
        region_name: isOnline ? null : (input.regionName ?? null),
        postal_code: isOnline ? null : (input.postalCode ?? null),
        country_code: isOnline ? null : input.countryCode,
        timezone: input.timezone,
        starts_at: input.startsAt,
        ends_at: input.endsAt,
        lifespan_days: input.lifespanDays,
        audiences: input.audiences,
        status: 'active',
        reviewed_by: userId,
        reviewed_at: reviewedAt,
      })
      .select('*')
      .single();

    throwDatabaseError(error, 'Unable to create the event.');
    return created(
      toEventResponse(
        {
          ...data,
          attendee_count: 0,
          view_count: 0,
          approved_at: reviewedAt,
          expires_at: new Date(
            new Date(reviewedAt).getTime() + input.lifespanDays * 86_400_000,
          ).toISOString(),
        },
        true,
      ),
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
