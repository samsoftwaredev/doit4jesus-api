import { GET } from '../src/app/api/v1/usernames/validate/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);

function usernameAvailability(occupied: string[] = []) {
  const occupiedNames = new Set(occupied.map((name) => name.toLowerCase()));
  return jest.fn(
    async (_functionName: string, args: { p_usernames: string[] }) => ({
      data: args.p_usernames.map((username) => ({
        username,
        is_available: !occupiedNames.has(username.toLowerCase()),
      })),
      error: null,
    }),
  );
}

describe('GET /api/v1/usernames/validate', () => {
  it('reports a case-insensitive duplicate and returns five available suggestions', async () => {
    const rpc = usernameAvailability(['TakenName']);
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await GET({
      url: 'http://localhost/api/v1/usernames/validate?username=TakenName',
    } as Request);

    expect(rpc).toHaveBeenCalledWith(
      'check_username_availability',
      expect.objectContaining({
        p_usernames: expect.arrayContaining(['TakenName']),
      }),
    );
    const body = await response.json();
    expect(body).toEqual({
      data: {
        username: 'TakenName',
        normalizedUsername: 'takenname',
        valid: true,
        available: false,
        reason: 'USERNAME_TAKEN',
        suggestions: expect.any(Array),
      },
    });
    expect(body.data.suggestions).toHaveLength(5);
    expect(response.headers.get('Cache-Control')).toBe('no-store');
  });

  it('rejects prohibited input without sending it to the availability RPC', async () => {
    const rpc = usernameAvailability();
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await GET({
      url: 'http://localhost/api/v1/usernames/validate?username=n1gga',
    } as Request);
    const calledCandidates = rpc.mock.calls[0][1].p_usernames;

    expect(calledCandidates).not.toContain('n1gga');
    const body = await response.json();
    expect(body).toEqual({
      data: {
        username: 'n1gga',
        normalizedUsername: 'n1gga',
        valid: false,
        available: false,
        reason: 'PROHIBITED_TERM',
        suggestions: expect.any(Array),
      },
    });
    expect(body.data.suggestions).toHaveLength(5);
  });
});
