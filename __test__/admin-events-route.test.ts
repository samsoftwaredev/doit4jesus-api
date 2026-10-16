import { PATCH } from '../src/app/api/v1/admin/events/[eventId]/route';
import { GET, POST } from '../src/app/api/v1/admin/events/route';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));

jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, _init: unknown, meta?: unknown) => ({
    status: 200,
    json: async () => (meta ? { data, meta } : { data }),
  }),
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  errorResponse: (error: unknown) => {
    throw error;
  },
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const USER_ID = '11111111-1111-4111-8111-111111111111';
const EVENT_ID = '22222222-2222-4222-8222-222222222222';

const event = {
  id: EVENT_ID,
  creator_id: USER_ID,
  title: 'Online Rosary',
  description: 'Pray with us.',
  image_url: null,
  event_url: null,
  event_type: 'online' as const,
  online_url: 'https://example.com/live',
  location_name: null,
  address_line_1: null,
  address_line_2: null,
  city: null,
  region_name: null,
  postal_code: null,
  country_code: null,
  timezone: 'America/Chicago',
  starts_at: '2026-11-01T01:00:00.000Z',
  ends_at: '2026-11-01T02:00:00.000Z',
  lifespan_days: 14,
  audiences: ['all'] as (
    | 'all'
    | 'kids'
    | 'youth'
    | 'men'
    | 'women'
    | 'single'
    | 'married'
  )[],
  status: 'pending' as const,
  reviewed_by: null,
  reviewed_at: null,
  created_at: '2026-10-20T00:00:00.000Z',
  updated_at: '2026-10-20T00:00:00.000Z',
};

function createQuery(data: unknown) {
  const query: Record<string, jest.Mock | ((...args: unknown[]) => unknown)> =
    {};
  for (const method of ['select', 'order', 'eq', 'range', 'insert']) {
    query[method] = jest.fn(() => query);
  }
  query.single = jest.fn().mockResolvedValue({ data, error: null });
  query.then = (onFulfilled: (result: unknown) => unknown) =>
    Promise.resolve({ data, error: null }).then(onFulfilled);
  return query;
}

describe('administrator event routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('filters events, directly publishes an admin event, and reviews a pending event', async () => {
    const listQuery = createQuery([event]);
    const insertQuery = createQuery({
      ...event,
      status: 'active',
      reviewed_by: USER_ID,
      reviewed_at: '2026-10-20T00:00:00.000Z',
    });
    const from = jest.fn((table: string) =>
      table === 'admin_event_summaries' ? listQuery : insertQuery,
    );
    const rpc = jest.fn().mockResolvedValue({
      data: {
        id: EVENT_ID,
        status: 'active',
        reviewedAt: '2026-10-20T00:00:00.000Z',
        expiresAt: '2026-11-03T00:00:00.000Z',
      },
      error: null,
    });
    mockedRequireAdmin.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from, rpc })) },
      userId: USER_ID,
    } as never);

    const listResponse = await GET({
      url: 'http://localhost/api/v1/admin/events?status=pending&limit=1&offset=2',
    } as Request);
    const createResponse = await POST({
      headers: { get: () => 'application/json' },
      json: async () => ({
        title: event.title,
        description: event.description,
        eventType: 'online',
        onlineUrl: event.online_url,
        timezone: event.timezone,
        startsAt: event.starts_at,
        endsAt: event.ends_at,
        lifespanDays: event.lifespan_days,
        audiences: event.audiences,
      }),
    } as Request);
    const reviewResponse = await PATCH(
      {
        headers: { get: () => 'application/json' },
        json: async () => ({ decision: 'active' }),
      } as Request,
      { params: Promise.resolve({ eventId: EVENT_ID }) },
    );

    expect(listQuery.eq).toHaveBeenCalledWith('status', 'pending');
    expect(listQuery.range).toHaveBeenCalledWith(2, 3);
    expect(insertQuery.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        creator_id: USER_ID,
        status: 'active',
        reviewed_by: USER_ID,
      }),
    );
    expect(rpc).toHaveBeenCalledWith('review_event', {
      p_event_id: EVENT_ID,
      p_decision: 'active',
    });
    expect((await listResponse.json()).data[0].status).toBe('pending');
    expect((await createResponse.json()).data.status).toBe('active');
    expect((await reviewResponse.json()).data.status).toBe('active');
  });
});
