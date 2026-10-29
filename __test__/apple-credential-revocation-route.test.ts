import { POST } from '../src/app/api/v1/me/apple-credential-revocation/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  noContent: () => ({ status: 204 }),
  errorResponse: (error: unknown) => {
    throw error;
  },
}));

const mockedRequireUser = jest.mocked(requireUser);
const request = {
  url: 'http://localhost/api/v1/me/apple-credential-revocation',
  headers: {
    get: (name: string) =>
      name === 'content-type'
        ? 'application/json'
        : name === 'x-request-id'
          ? 'test-request-id'
          : null,
  },
  json: async () => ({ authorizationCode: 'fresh-apple-code' }),
} as unknown as Request;

describe('Apple credential revocation route', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.APPLE_CLIENT_ID = 'doit4jesus.com';
    process.env.APPLE_CLIENT_SECRET = 'signed-client-secret';
    mockedRequireUser.mockResolvedValue({
      userId: '11111111-1111-4111-8111-111111111111',
    } as never);
  });

  afterEach(() => {
    delete process.env.APPLE_CLIENT_ID;
    delete process.env.APPLE_CLIENT_SECRET;
  });

  it('exchanges a fresh authorization code and revokes the refresh token', async () => {
    globalThis.fetch = jest
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ refresh_token: 'apple-refresh-token' }),
      })
      .mockResolvedValueOnce({ ok: true });

    const response = await POST(request);

    expect(response.status).toBe(204);
    expect(globalThis.fetch).toHaveBeenNthCalledWith(
      2,
      'https://appleid.apple.com/auth/revoke',
      expect.objectContaining({ method: 'POST' }),
    );
    const revokeBody = (globalThis.fetch as jest.Mock).mock.calls[1][1]
      .body as URLSearchParams;
    expect(revokeBody.get('token')).toBe('apple-refresh-token');
    expect(revokeBody.get('token_type_hint')).toBe('refresh_token');
  });
});
