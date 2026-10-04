import { GET } from '../src/app/api/v1/activities/route';
import { ApiError } from '../src/lib/api/errors';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (
    data: unknown,
    _init?: ResponseInit,
    meta?: Record<string, unknown>,
  ) => ({
    status: 200,
    json: async () => (meta ? { data, meta } : { data }),
  }),
  errorResponse: (error: { status?: number; code?: string; name?: string }) => {
    const isValidationError = error.name === 'ZodError';
    const status = isValidationError ? 422 : (error.status ?? 500);
    return {
      status,
      json: async () => ({
        error: {
          code: isValidationError
            ? 'VALIDATION_ERROR'
            : (error.code ?? 'INTERNAL_ERROR'),
        },
      }),
    };
  },
}));

const mockedRequireUser = jest.mocked(requireUser);

const activities = [
  {
    id: 'activity-1',
    activity_code: 'ROSARY',
    occurred_at: '2026-10-03T10:00:00Z',
  },
  {
    id: 'activity-2',
    activity_code: 'SCRIPTURE',
    occurred_at: '2026-10-02T10:00:00Z',
  },
  {
    id: 'activity-3',
    activity_code: 'PRAYER',
    occurred_at: '2026-10-01T10:00:00Z',
  },
];

function queryResult(data: unknown, error: unknown = null) {
  const query = {
    select: jest.fn(),
    eq: jest.fn(),
    order: jest.fn(),
    limit: jest.fn(),
    lt: jest.fn(),
    in: jest.fn(),
    then: (
      resolve: (value: unknown) => unknown,
      reject: (reason: unknown) => unknown,
    ) => Promise.resolve({ data, error }).then(resolve, reject),
  };

  for (const method of [
    'select',
    'eq',
    'order',
    'limit',
    'lt',
    'in',
  ] as const) {
    query[method].mockReturnValue(query);
  }

  return query;
}

function setup({
  activityRows = activities,
  pointRows = [],
  activityError = null,
  pointsError = null,
}: {
  activityRows?: unknown;
  pointRows?: unknown;
  activityError?: unknown;
  pointsError?: unknown;
} = {}) {
  const activityQuery = queryResult(activityRows, activityError);
  const pointQuery = queryResult(pointRows, pointsError);
  const from = jest.fn((table: string) =>
    table === 'spiritual_activities' ? activityQuery : pointQuery,
  );

  mockedRequireUser.mockResolvedValue({
    userId: 'user-1',
    supabase: { schema: jest.fn(() => ({ from })) },
  } as never);

  return { activityQuery, pointQuery, from };
}

function request(query = '') {
  return {
    url: `https://example.test/api/v1/activities${query}`,
    headers: {
      get: (name: string) => (name === 'x-request-id' ? 'test-id' : null),
    },
  } as Request;
}

describe('GET /api/v1/activities', () => {
  beforeEach(() => jest.clearAllMocks());

  it('preserves the default activity response without loading points', async () => {
    const { pointQuery } = setup({ activityRows: activities.slice(0, 2) });

    const response = await GET(request('?limit=2'));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      data: activities.slice(0, 2),
      meta: { limit: 2, hasMore: false, nextCursor: null },
    });
    expect(pointQuery.select).not.toHaveBeenCalled();
  });

  it('adds signed net points only for the returned activity page', async () => {
    const { activityQuery, pointQuery } = setup({
      pointRows: [
        { activity_id: 'activity-1', points: 25 },
        { activity_id: 'activity-1', points: -10 },
        { activity_id: 'activity-2', points: 20 },
        { activity_id: 'activity-3', points: 99 },
      ],
    });

    const response = await GET(request('?limit=2&include=points'));

    expect(await response.json()).toEqual({
      data: [
        { ...activities[0], points: 15 },
        { ...activities[1], points: 20 },
      ],
      meta: { limit: 2, hasMore: true, nextCursor: activities[1].occurred_at },
    });
    expect(activityQuery.limit).toHaveBeenCalledWith(3);
    expect(pointQuery.eq).toHaveBeenCalledWith('user_id', 'user-1');
    expect(pointQuery.in).toHaveBeenCalledWith('activity_id', [
      'activity-1',
      'activity-2',
    ]);
  });

  it('returns zero points when an activity has no point-ledger entries', async () => {
    setup({ activityRows: activities.slice(0, 1) });

    const response = await GET(request('?include=points'));

    expect(await response.json()).toEqual({
      data: [{ ...activities[0], points: 0 }],
      meta: { limit: 20, hasMore: false, nextCursor: null },
    });
  });

  it('normalizes activity filters while preserving the cursor', async () => {
    const { activityQuery } = setup({ activityRows: [] });

    await GET(request('?activityCode=rosary&before=2026-10-02T10%3A00%3A00Z'));

    expect(activityQuery.eq).toHaveBeenCalledWith('activity_code', 'ROSARY');
    expect(activityQuery.lt).toHaveBeenCalledWith(
      'occurred_at',
      '2026-10-02T10:00:00Z',
    );
  });

  it('rejects unsupported include values', async () => {
    setup();

    const response = await GET(request('?include=ledger'));

    expect(response.status).toBe(422);
    expect((await response.json()).error.code).toBe('VALIDATION_ERROR');
  });

  it('returns the standard authentication error', async () => {
    mockedRequireUser.mockRejectedValue(ApiError.unauthorized());

    const response = await GET(request());

    expect(response.status).toBe(401);
  });

  it('returns the standard safe error when point loading fails', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    setup({ pointsError: { code: 'XX000', message: 'internal details' } });

    const response = await GET(request('?include=points'));
    const body = await response.json();

    expect(response.status).toBe(500);
    expect(body.error.code).toBe('DATABASE_ERROR');
    expect(JSON.stringify(body)).not.toContain('internal details');
  });
});
