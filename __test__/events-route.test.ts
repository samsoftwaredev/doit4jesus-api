import {
  DELETE as cancelRsvp,
  POST as rsvp,
} from '../src/app/api/v1/events/[eventId]/attendance/route';
import { GET as getEvent } from '../src/app/api/v1/events/[eventId]/route';
import {
  GET as getEvents,
  POST as postEvent,
} from '../src/app/api/v1/events/route';
import { requireUser } from '../src/lib/auth/require-user';
import { createEventSchema } from '../src/lib/schemas/events';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, _init: unknown, meta?: unknown) => ({
    status: 200,
    json: async () => (meta ? { data, meta } : { data }),
  }),
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  noContent: () => ({ status: 204 }),
  errorResponse: (error: unknown) => {
    throw error;
  },
}));

const mockedRequireUser = jest.mocked(requireUser);

const USER_ID = '11111111-1111-4111-8111-111111111111';
const EVENT_ID = '22222222-2222-4222-8222-222222222222';

const event = {
  id: EVENT_ID,
  creator_id: USER_ID,
  title: 'Catholic Youth Night',
  description: 'Bring a friend.',
  image_url: 'https://example.com/youth-night.png',
  event_url: 'https://example.com/register',
  event_type: 'physical' as const,
  online_url: null,
  location_name: 'St. Thomas More Catholic Church',
  address_line_1: '10205 FM 620 N',
  address_line_2: null,
  city: 'Austin',
  region_name: 'Texas',
  postal_code: '78726',
  country_code: 'US',
  timezone: 'America/Chicago',
  starts_at: '2026-11-01T00:00:00.000Z',
  ends_at: '2026-11-01T02:00:00.000Z',
  lifespan_days: 30,
  audiences: ['youth'] as (
    | 'all'
    | 'kids'
    | 'youth'
    | 'men'
    | 'women'
    | 'single'
    | 'married'
  )[],
  status: 'active' as const,
  reviewed_by: USER_ID,
  reviewed_at: '2026-10-20T00:00:00.000Z',
  approved_at: '2026-10-20T00:00:00.000Z',
  expires_at: '2026-11-19T00:00:00.000Z',
  created_at: '2026-10-19T00:00:00.000Z',
  updated_at: '2026-10-20T00:00:00.000Z',
  attendee_count: 4,
  view_count: 9,
};

function createQuery(data: unknown) {
  const query: Record<string, jest.Mock | ((...args: unknown[]) => unknown)> =
    {};
  for (const method of ['select', 'order', 'range', 'eq', 'insert']) {
    query[method] = jest.fn(() => query);
  }
  query.single = jest.fn().mockResolvedValue({ data, error: null });
  query.maybeSingle = jest.fn().mockResolvedValue({ data, error: null });
  query.then = (onFulfilled: (result: unknown) => unknown) =>
    Promise.resolve({ data, error: null }).then(onFulfilled);
  return query;
}

function request(url: string, body?: unknown) {
  return {
    url,
    headers: { get: () => 'application/json' },
    json: async () => body,
  } as Request;
}

describe('event routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('lists approved event cards and submits physical events as pending', async () => {
    const listQuery = createQuery([event, { ...event, id: USER_ID }]);
    const insertQuery = createQuery({
      ...event,
      status: 'pending',
      reviewed_by: null,
      reviewed_at: null,
      approved_at: undefined,
      expires_at: null,
    });
    const from = jest.fn((table: string) =>
      table === 'event_cards' ? listQuery : insertQuery,
    );
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId: USER_ID,
    } as never);

    const listResponse = await getEvents(
      request('http://localhost/api/v1/events?limit=1&offset=2'),
    );
    const createResponse = await postEvent(
      request('http://localhost/api/v1/events', {
        title: event.title,
        description: event.description,
        imageUrl: event.image_url,
        eventUrl: event.event_url,
        eventType: 'physical',
        locationName: event.location_name,
        addressLine1: event.address_line_1,
        city: event.city,
        regionName: event.region_name,
        postalCode: event.postal_code,
        countryCode: event.country_code,
        timezone: event.timezone,
        startsAt: event.starts_at,
        endsAt: event.ends_at,
        lifespanDays: event.lifespan_days,
        audiences: event.audiences,
      }),
    );

    expect(listQuery.range).toHaveBeenCalledWith(2, 3);
    expect((await listResponse.json()).data[0]).toMatchObject({
      id: EVENT_ID,
      location: { city: 'Austin', countryCode: 'US' },
      attendeeCount: 4,
      viewCount: 9,
    });
    expect(createResponse.status).toBe(201);
    expect(insertQuery.insert).toHaveBeenCalledWith(
      expect.objectContaining({ creator_id: USER_ID, event_type: 'physical' }),
    );
    expect((await createResponse.json()).data.status).toBe('pending');
  });

  it('records a unique detail view and allows RSVP cancellation', async () => {
    const eventQuery = createQuery(event);
    const rpc = jest
      .fn()
      .mockResolvedValueOnce({
        data: { eventId: EVENT_ID, viewCount: 10 },
        error: null,
      })
      .mockResolvedValueOnce({
        data: { eventId: EVENT_ID, rsvpCreated: true, attendeeCount: 5 },
        error: null,
      })
      .mockResolvedValueOnce({ data: null, error: null });
    mockedRequireUser.mockResolvedValue({
      supabase: {
        schema: jest.fn((schema: string) =>
          schema === 'app' ? { from: jest.fn(() => eventQuery) } : { rpc },
        ),
      },
      userId: USER_ID,
    } as never);

    const context = { params: Promise.resolve({ eventId: EVENT_ID }) };
    const detailResponse = await getEvent(
      request(`http://localhost/api/v1/events/${EVENT_ID}`),
      context,
    );
    const rsvpResponse = await rsvp(
      request(`http://localhost/api/v1/events/${EVENT_ID}/attendance`),
      context,
    );
    const cancelResponse = await cancelRsvp(
      request(`http://localhost/api/v1/events/${EVENT_ID}/attendance`),
      context,
    );

    expect((await detailResponse.json()).data.viewCount).toBe(10);
    expect((await rsvpResponse.json()).data).toMatchObject({
      rsvpCreated: true,
      attendeeCount: 5,
    });
    expect(cancelResponse.status).toBe(204);
    expect(rpc).toHaveBeenCalledWith('record_event_view', {
      p_event_id: EVENT_ID,
    });
    expect(rpc).toHaveBeenCalledWith('rsvp_to_event', { p_event_id: EVENT_ID });
    expect(rpc).toHaveBeenCalledWith('cancel_event_rsvp', {
      p_event_id: EVENT_ID,
    });
  });

  it('requires valid event timing and enforces one location shape', () => {
    expect(
      createEventSchema.safeParse({
        title: 'Young Adult Fellowship',
        description: 'Meet other parishioners.',
        eventType: 'online',
        onlineUrl: 'https://example.com/live',
        timezone: 'America/Chicago',
        startsAt: '2026-11-01T01:00:00.000Z',
        endsAt: '2026-11-01T02:00:00.000Z',
        lifespanDays: 7,
        audiences: ['single', 'men'],
      }).success,
    ).toBe(true);
    expect(
      createEventSchema.safeParse({
        title: 'Online Prayer',
        description: 'Join us.',
        eventType: 'online',
        onlineUrl: 'https://example.com/live',
        timezone: 'America/Chicago',
        startsAt: '2026-11-01T02:00:00.000Z',
        endsAt: '2026-11-01T01:00:00.000Z',
        lifespanDays: 7,
        audiences: ['all'],
      }).success,
    ).toBe(false);
    expect(
      createEventSchema.safeParse({
        title: 'Online Prayer',
        description: 'Join us.',
        eventType: 'online',
        onlineUrl: 'https://example.com/live',
        city: 'Austin',
        timezone: 'America/Chicago',
        startsAt: '2026-11-01T01:00:00.000Z',
        endsAt: '2026-11-01T02:00:00.000Z',
        lifespanDays: 7,
        audiences: ['all'],
      }).success,
    ).toBe(false);
  });
});
