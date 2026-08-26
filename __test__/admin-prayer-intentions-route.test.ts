import { PATCH } from '../src/app/api/v1/admin/prayer-intentions/[intentionId]/route';
import { GET } from '../src/app/api/v1/admin/prayer-intentions/route';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));

jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, _init: unknown, meta?: unknown) => ({
    status: 200,
    json: async () => (meta ? { data, meta } : { data }),
  }),
  errorResponse: (error: unknown) => {
    throw error;
  },
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);

const INTENTION_ID = '22222222-2222-4222-8222-222222222222';

function createListQuery(rows: unknown[]) {
  const query: Record<string, jest.Mock | ((...args: unknown[]) => unknown)> =
    {};
  for (const method of ['select', 'order', 'eq', 'gte', 'lt', 'range']) {
    query[method] = jest.fn(() => query);
  }
  query.then = (onFulfilled: (result: unknown) => unknown) =>
    Promise.resolve({ data: rows, error: null }).then(onFulfilled);
  return query;
}

describe('administrator prayer intention routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('filters the review queue and reviews a pending intention through the RPC', async () => {
    const row = {
      id: INTENTION_ID,
      creator_id: '11111111-1111-4111-8111-111111111111',
      title: 'Praying for my brother',
      description: 'He is currently having back pain.',
      symbol: null,
      status: 'pending',
      reviewed_by: null,
      reviewed_at: null,
      expires_at: null,
      created_at: '2026-08-24T12:00:00.000Z',
    };
    const query = createListQuery([row]);
    const from = jest.fn(() => query);
    const rpc = jest.fn().mockResolvedValue({
      data: {
        id: INTENTION_ID,
        status: 'visible',
        reviewedAt: '2026-08-24T12:00:00.000Z',
        expiresAt: '2026-09-24T12:00:00.000Z',
      },
      error: null,
    });
    mockedRequireAdmin.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from, rpc })) },
    } as never);

    const listResponse = await GET({
      url: 'http://localhost/api/v1/admin/prayer-intentions?status=pending&createdAt=2026-08-24&limit=1&offset=2',
    } as Request);
    const reviewResponse = await PATCH(
      {
        headers: { get: () => 'application/json' },
        json: async () => ({ decision: 'visible' }),
      } as Request,
      { params: Promise.resolve({ intentionId: INTENTION_ID }) },
    );

    expect(from).toHaveBeenCalledWith('prayer_intentions');
    expect(query.eq).toHaveBeenCalledWith('status', 'pending');
    expect(query.gte).toHaveBeenCalledWith(
      'created_at',
      '2026-08-24T00:00:00.000Z',
    );
    expect(query.lt).toHaveBeenCalledWith(
      'created_at',
      '2026-08-25T00:00:00.000Z',
    );
    expect(query.range).toHaveBeenCalledWith(2, 3);
    expect(rpc).toHaveBeenCalledWith('review_prayer_intention', {
      p_intention_id: INTENTION_ID,
      p_decision: 'visible',
    });
    expect((await listResponse.json()).data[0]).toMatchObject({
      creatorId: row.creator_id,
      status: 'pending',
    });
    expect((await reviewResponse.json()).data).toMatchObject({
      id: INTENTION_ID,
      status: 'visible',
    });
  });
});
