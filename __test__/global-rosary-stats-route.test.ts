import { GET } from '../src/app/api/v1/rosary/stats/route';
import { getOptionalUser } from '../src/lib/auth/optional-user';

jest.mock('../src/lib/auth/optional-user', () => ({
  getOptionalUser: jest.fn(),
}));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, init?: ResponseInit) => ({
    status: 200,
    json: async () => ({ data }),
    headers: {
      get: (name: string) => {
        const headers = init?.headers as Record<string, string> | undefined;
        return (
          Object.entries(headers ?? {}).find(
            ([key]) => key.toLowerCase() === name.toLowerCase(),
          )?.[1] ?? null
        );
      },
    },
  }),
  errorResponse: () => ({
    status: 500,
    json: async () => ({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred.',
      },
    }),
  }),
}));

const mockedGetOptionalUser = jest.mocked(getOptionalUser);

function request(authorization?: string) {
  return {
    headers: {
      get: (name: string) =>
        name.toLowerCase() === 'authorization' ? (authorization ?? null) : null,
    },
  } as Request;
}

function optionalUserWithRpc(data: unknown, error: unknown = null) {
  const rpc = jest.fn().mockResolvedValue({ data, error });
  mockedGetOptionalUser.mockResolvedValue({
    supabase: { schema: jest.fn(() => ({ rpc })) },
    userId: null,
    claims: {},
    authMode: 'anonymous',
  } as never);
  return rpc;
}

describe('GET /api/v1/rosary/stats', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns the anonymous global total without a user contribution', async () => {
    const data = {
      totalRosariesPrayed: 12345,
      currentUserContribution: null,
    };
    const rpc = optionalUserWithRpc(data);

    const response = await GET(request());

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ data });
    expect(rpc).toHaveBeenCalledWith('get_global_rosary_stats');
    expect(response.headers.get('cache-control')).toBe('private, no-store');
    expect(response.headers.get('vary')).toBe('Authorization, Cookie');
  });

  it('returns an authenticated user contribution', async () => {
    const data = {
      totalRosariesPrayed: 12345,
      currentUserContribution: {
        rosariesPrayed: 42,
        percentage: 0.3402,
      },
    };
    optionalUserWithRpc(data);

    const response = await GET(request('Bearer valid-token'));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ data });
  });

  it('returns the standard safe error when the database call fails', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    optionalUserWithRpc(null, {
      code: 'XX000',
      message: 'internal details',
      details: null,
      hint: null,
    });

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(500);
    expect(body.error).toMatchObject({
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred.',
    });
    expect(JSON.stringify(body)).not.toContain('internal details');
  });
});
