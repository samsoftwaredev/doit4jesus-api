import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { toEventResponse } from '@/lib/events/presentation';
import { createEventSchema, eventFeedQuerySchema } from '@/lib/schemas/events';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = eventFeedQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('app')
      .from('event_cards')
      .select('*')
      .order('starts_at', { ascending: true })
      .order('id', { ascending: true })
      .range(query.offset, query.offset + query.limit);

    throwDatabaseError(error, 'Unable to load events.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    return ok(
      rows.slice(0, query.limit).map((row) => toEventResponse(row)),
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
    const input = createEventSchema.parse(await readJson(request));
    const isOnline = input.eventType === 'online';
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
      })
      .select('*')
      .single();

    throwDatabaseError(error, 'Unable to submit the event.');
    return created(
      toEventResponse(
        { ...data, attendee_count: 0, view_count: 0, expires_at: null },
        true,
      ),
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
