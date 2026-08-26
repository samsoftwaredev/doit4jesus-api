import { GET as getMyPrayerIntentions } from '../src/app/api/v1/me/prayer-intentions/route';
import { GET as getPrayerIntention } from '../src/app/api/v1/prayer-intentions/[intentionId]/route';
import {
  GET as getPrayerIntentions,
  POST as postPrayerIntention,
} from '../src/app/api/v1/prayer-intentions/route';
import { requireUser } from '../src/lib/auth/require-user';
import { createPrayerIntentionSchema } from '../src/lib/schemas/prayer-intention';

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

const USER_ID = '11111111-1111-4111-8111-111111111111';
const INTENTION_ID = '22222222-2222-4222-8222-222222222222';

function createQuery(data: unknown) {
  const query: Record<string, jest.Mock | ((...args: unknown[]) => unknown)> =
    {};

  for (const method of ['select', 'order', 'range', 'or', 'eq', 'insert']) {
    query[method] = jest.fn(() => query);
  }

  query.then = (onFulfilled: (result: unknown) => unknown) =>
    Promise.resolve({ data, error: null }).then(onFulfilled);
  query.single = jest.fn().mockResolvedValue({ data, error: null });
  query.maybeSingle = jest.fn().mockResolvedValue({ data, error: null });

  return query;
}

function request(
  url: string,
  body?: unknown,
  contentType = 'application/json',
) {
  return {
    url,
    headers: {
      get: (name: string) => (name === 'content-type' ? contentType : null),
    },
    json: async () => body,
  } as Request;
}

describe('prayer intention routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns only card-ready fields for approved public intentions', async () => {
    const card = {
      id: INTENTION_ID,
      title: 'Praying for my brother',
      description: 'He is currently having back pain.',
      symbol: 'candle',
      approved_at: '2026-08-24T12:00:00.000Z',
      expires_at: '2026-09-24T12:00:00.000Z',
      created_at: '2026-08-23T12:00:00.000Z',
      creator_display_name: 'Michael R.',
      creator_avatar_url: 'https://example.com/michael.png',
      creator_country_code: 'US',
      prayer_count: 4,
    };
    const query = createQuery([card, { ...card, id: USER_ID }]);
    const from = jest.fn(() => query);
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId: USER_ID,
    } as never);

    const response = await getPrayerIntentions(
      request('http://localhost/api/v1/prayer-intentions?limit=1&offset=2'),
    );

    expect(from).toHaveBeenCalledWith('prayer_intention_cards');
    expect(query.range).toHaveBeenCalledWith(2, 3);
    expect(await response.json()).toEqual({
      data: [
        {
          id: INTENTION_ID,
          title: 'Praying for my brother',
          description: 'He is currently having back pain.',
          symbol: 'candle',
          approvedAt: '2026-08-24T12:00:00.000Z',
          expiresAt: '2026-09-24T12:00:00.000Z',
          createdAt: '2026-08-23T12:00:00.000Z',
          prayerCount: 4,
          creator: {
            displayName: 'Michael R.',
            avatarUrl: 'https://example.com/michael.png',
            countryCode: 'US',
          },
        },
      ],
      meta: { limit: 1, offset: 2, hasMore: true, nextOffset: 3 },
    });
  });

  it('submits a pending intention and enforces the 250-character description limit', async () => {
    const row = {
      id: INTENTION_ID,
      creator_id: USER_ID,
      title: 'Praying for my brother',
      description: 'He is currently having back pain.',
      symbol: 'candle',
      status: 'pending',
      created_at: '2026-08-23T12:00:00.000Z',
      reviewed_at: null,
      expires_at: null,
    };
    const query = createQuery(row);
    const from = jest.fn(() => query);
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId: USER_ID,
    } as never);

    const response = await postPrayerIntention(
      request('http://localhost/api/v1/prayer-intentions', {
        title: row.title,
        description: row.description,
        symbol: row.symbol,
      }),
    );

    expect(response.status).toBe(201);
    expect((await response.json()).data.prayerCount).toBe(0);
    expect(query.insert).toHaveBeenCalledWith({
      creator_id: USER_ID,
      title: row.title,
      description: row.description,
      symbol: 'candle',
    });
    expect(
      createPrayerIntentionSchema.safeParse({
        title: 'Prayer',
        description: 'a'.repeat(251),
      }).success,
    ).toBe(false);
    expect(
      createPrayerIntentionSchema.safeParse({
        title: 'Prayer for peace',
        description: 'Please pray for peace.',
        symbol: 'olive_branch',
      }).success,
    ).toBe(true);
    expect(
      createPrayerIntentionSchema.safeParse({
        title: 'Prayer for peace',
        description: 'Please pray for peace.',
        symbol: 'rosary',
      }).success,
    ).toBe(false);
  });

  it('gets one approved, unexpired intention by ID', async () => {
    const card = {
      id: INTENTION_ID,
      title: 'Praying for my brother',
      description: 'He is currently having back pain.',
      symbol: 'olive_branch',
      approved_at: '2026-08-24T12:00:00.000Z',
      expires_at: '2026-09-24T12:00:00.000Z',
      created_at: '2026-08-23T12:00:00.000Z',
      creator_display_name: 'Michael R.',
      creator_avatar_url: 'https://example.com/michael.png',
      creator_country_code: 'US',
      prayer_count: 4,
    };
    const query = createQuery(card);
    const from = jest.fn(() => query);
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId: USER_ID,
    } as never);

    const response = await getPrayerIntention(
      request(`http://localhost/api/v1/prayer-intentions/${INTENTION_ID}`),
      { params: Promise.resolve({ intentionId: INTENTION_ID }) },
    );

    expect(from).toHaveBeenCalledWith('prayer_intention_cards');
    expect(query.eq).toHaveBeenCalledWith('id', INTENTION_ID);
    expect((await response.json()).data).toMatchObject({
      id: INTENTION_ID,
      symbol: 'olive_branch',
      prayerCount: 4,
      creator: { countryCode: 'US' },
    });
  });

  it('lists the current user intentions without leaking expired rows', async () => {
    const row = {
      id: INTENTION_ID,
      title: 'Praying for my brother',
      description: 'He is currently having back pain.',
      symbol: null,
      status: 'rejected',
      created_at: '2026-08-23T12:00:00.000Z',
      reviewed_at: '2026-08-24T12:00:00.000Z',
      expires_at: '2026-09-24T12:00:00.000Z',
      prayer_count: 4,
    };
    const query = createQuery([row]);
    const from = jest.fn(() => query);
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId: USER_ID,
    } as never);

    const response = await getMyPrayerIntentions(
      request('http://localhost/api/v1/me/prayer-intentions?status=rejected'),
    );

    expect(from).toHaveBeenCalledWith('my_prayer_intention_summaries');
    expect(query.eq).toHaveBeenCalledWith('status', 'rejected');
    expect((await response.json()).data[0]).toMatchObject({
      id: INTENTION_ID,
      status: 'rejected',
      expiresAt: row.expires_at,
      prayerCount: 4,
    });
  });
});
