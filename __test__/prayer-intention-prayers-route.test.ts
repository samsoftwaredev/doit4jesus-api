import {
  GET,
  POST,
} from '../src/app/api/v1/prayer-intentions/[intentionId]/prayers/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

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

const mockedRequireUser = jest.mocked(requireUser);

const CREATOR_ID = '11111111-1111-4111-8111-111111111111';
const PRAYER_ID = '33333333-3333-4333-8333-333333333333';
const INTENTION_ID = '22222222-2222-4222-8222-222222222222';

function createQuery(data: unknown) {
  const query: Record<string, jest.Mock | ((...args: unknown[]) => unknown)> =
    {};

  for (const method of ['select', 'eq', 'order', 'range']) {
    query[method] = jest.fn(() => query);
  }

  query.then = (onFulfilled: (result: unknown) => unknown) =>
    Promise.resolve({ data, error: null }).then(onFulfilled);
  query.maybeSingle = jest.fn().mockResolvedValue({ data, error: null });

  return query;
}

describe('prayer intention prayer routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('records an append-only prayer for a visible intention', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: {
        id: PRAYER_ID,
        intentionId: INTENTION_ID,
        prayedAt: '2026-08-25T12:00:00.000Z',
        prayerCount: 5,
      },
      error: null,
    });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
      userId: CREATOR_ID,
    } as never);

    const response = await POST({} as Request, {
      params: Promise.resolve({ intentionId: INTENTION_ID }),
    });

    expect(rpc).toHaveBeenCalledWith('record_prayer_intention_prayer', {
      p_intention_id: INTENTION_ID,
    });
    expect(await response.json()).toEqual({
      data: {
        id: PRAYER_ID,
        intentionId: INTENTION_ID,
        prayedAt: '2026-08-25T12:00:00.000Z',
        prayerCount: 5,
      },
    });
  });

  it('lets a creator list prayer records with card-safe user fields', async () => {
    const intentionQuery = createQuery({ id: INTENTION_ID });
    const participantQuery = createQuery([
      {
        id: PRAYER_ID,
        intention_id: INTENTION_ID,
        user_id: CREATOR_ID,
        created_at: '2026-08-25T12:00:00.000Z',
        display_name: 'Michael R.',
        avatar_url: 'https://example.com/michael.png',
        country_code: 'US',
      },
    ]);
    const from = jest.fn((source: string) =>
      source === 'prayer_intentions' ? intentionQuery : participantQuery,
    );
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId: CREATOR_ID,
    } as never);

    const response = await GET(
      {
        url: `http://localhost/api/v1/prayer-intentions/${INTENTION_ID}/prayers?limit=1&offset=2`,
      } as Request,
      { params: Promise.resolve({ intentionId: INTENTION_ID }) },
    );

    expect(from).toHaveBeenCalledWith('prayer_intentions');
    expect(from).toHaveBeenCalledWith('prayer_intention_prayer_participants');
    expect(participantQuery.range).toHaveBeenCalledWith(2, 3);
    expect(await response.json()).toEqual({
      data: [
        {
          id: PRAYER_ID,
          user: {
            id: CREATOR_ID,
            displayName: 'Michael R.',
            avatarUrl: 'https://example.com/michael.png',
            countryCode: 'US',
          },
          prayedAt: '2026-08-25T12:00:00.000Z',
        },
      ],
      meta: { limit: 1, offset: 2, hasMore: false, nextOffset: null },
    });
  });
});
