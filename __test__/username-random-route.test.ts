import { GET } from '../src/app/api/v1/usernames/random/route';
import { ApiError } from '../src/lib/api/errors';
import { requireUser } from '../src/lib/auth/require-user';
import { evaluateUsername } from '../src/lib/usernames/moderation';
import { generateUsernameCandidates } from '../src/lib/usernames/suggestions';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, init: ResponseInit) => ({
    status: 200,
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
  errorResponse: (error: {
    status?: number;
    code?: string;
    message?: string;
  }) => ({
    status: error.status ?? 500,
    json: async () => ({
      error: {
        code: error.code ?? 'INTERNAL_ERROR',
        message: error.message ?? 'An unexpected error occurred.',
      },
    }),
  }),
}));
jest.mock('../src/lib/usernames/suggestions', () => ({
  generateUsernameCandidates: jest.fn(),
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedGenerateUsernameCandidates = jest.mocked(
  generateUsernameCandidates,
);

const candidates = [
  'faithful_clare1842',
  'monica_dove7391',
  'hopeful_pilgrim2318',
  'dominic_witness4430',
  'joyful_rosary8724',
  'humble_teresa6147',
  'kolbe_fisher9052',
];

function request() {
  return {
    url: 'http://localhost/api/v1/usernames/random',
    headers: new Headers(),
  } as Request;
}

function setupAvailability({
  occupied = [],
  error = null,
}: {
  occupied?: string[];
  error?: unknown;
} = {}) {
  const occupiedNames = new Set(occupied.map((name) => name.toLowerCase()));
  const rpc = jest.fn(
    async (_functionName: string, args: { p_usernames: string[] }) => ({
      data: error
        ? null
        : args.p_usernames.map((username) => ({
            username,
            is_available: !occupiedNames.has(username.toLowerCase()),
          })),
      error,
    }),
  );

  mockedRequireUser.mockResolvedValue({
    supabase: { schema: jest.fn(() => ({ rpc })) },
  } as never);

  return rpc;
}

describe('GET /api/v1/usernames/random', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedGenerateUsernameCandidates.mockReturnValue(candidates);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('returns five unique, valid, available usernames without caching', async () => {
    const rpc = setupAvailability({ occupied: candidates.slice(0, 2) });
    const apiRequest = request();

    const response = await GET(apiRequest);
    const body = await response.json();

    expect(mockedRequireUser).toHaveBeenCalledWith(apiRequest);
    expect(rpc).toHaveBeenCalledWith('check_username_availability', {
      p_usernames: candidates,
    });
    expect(body).toEqual({ data: { usernames: candidates.slice(2) } });
    expect(new Set(body.data.usernames).size).toBe(5);
    expect(
      body.data.usernames.every(
        (username: string) => evaluateUsername(username).valid,
      ),
    ).toBe(true);
    expect(response.headers.get('Cache-Control')).toBe('no-store');
  });

  it('returns a safe error when five available usernames cannot be found', async () => {
    setupAvailability({ occupied: candidates.slice(4) });

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(500);
    expect(body.error).toMatchObject({
      code: 'USERNAME_SUGGESTIONS_UNAVAILABLE',
      message: 'Unable to generate enough available username suggestions.',
    });
  });

  it('returns the standard authentication error', async () => {
    mockedRequireUser.mockRejectedValue(ApiError.unauthorized());

    const response = await GET(request());

    expect(response.status).toBe(401);
    expect((await response.json()).error.code).toBe('UNAUTHORIZED');
  });

  it('does not expose database failure details', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    setupAvailability({
      error: {
        code: 'XX000',
        message: 'internal database details',
        details: null,
        hint: null,
      },
    });

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(500);
    expect(body.error).toMatchObject({
      code: 'DATABASE_ERROR',
      message: 'Unable to generate username suggestions.',
    });
    expect(JSON.stringify(body)).not.toContain('internal database details');
  });
});
