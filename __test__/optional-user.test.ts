import { getOptionalUser } from '../src/lib/auth/optional-user';
import { createBearerClient } from '../src/lib/supabase/bearer';
import { createPublicClient } from '../src/lib/supabase/public';
import { createClient } from '../src/lib/supabase/server';

jest.mock('../src/lib/supabase/bearer', () => ({
  createBearerClient: jest.fn(),
}));
jest.mock('../src/lib/supabase/public', () => ({
  createPublicClient: jest.fn(),
}));
jest.mock('../src/lib/supabase/server', () => ({ createClient: jest.fn() }));

const mockedCreateBearerClient = jest.mocked(createBearerClient);
const mockedCreatePublicClient = jest.mocked(createPublicClient);
const mockedCreateClient = jest.mocked(createClient);

function request(authorization?: string) {
  return {
    headers: {
      get: (name: string) =>
        name.toLowerCase() === 'authorization' ? (authorization ?? null) : null,
    },
  } as Request;
}

function client(
  claims: Record<string, unknown> | null,
  error: Error | null = null,
) {
  return {
    auth: {
      getClaims: jest.fn().mockResolvedValue({
        data: claims ? { claims } : null,
        error,
      }),
    },
  };
}

describe('getOptionalUser', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('uses an authenticated Bearer client when the token is valid', async () => {
    const bearerClient = client({ sub: 'user-id' });
    mockedCreateBearerClient.mockReturnValue(bearerClient as never);

    const context = await getOptionalUser(request('Bearer valid-token'));

    expect(context).toMatchObject({ userId: 'user-id', authMode: 'bearer' });
    expect(bearerClient.auth.getClaims).toHaveBeenCalledWith('valid-token');
    expect(createPublicClient).not.toHaveBeenCalled();
  });

  it('uses an authenticated cookie client when a session exists', async () => {
    const cookieClient = client({ sub: 'user-id' });
    mockedCreateClient.mockResolvedValue(cookieClient as never);

    const context = await getOptionalUser(request());

    expect(context).toMatchObject({ userId: 'user-id', authMode: 'cookie' });
    expect(createPublicClient).not.toHaveBeenCalled();
  });

  it('uses the public client when no authenticated cookie session exists', async () => {
    const cookieClient = client(null);
    const publicClient = { public: true };
    mockedCreateClient.mockResolvedValue(cookieClient as never);
    mockedCreatePublicClient.mockReturnValue(publicClient as never);

    const context = await getOptionalUser(request());

    expect(context).toMatchObject({
      supabase: publicClient,
      userId: null,
      authMode: 'anonymous',
    });
  });

  it('rejects malformed and invalid Bearer credentials', async () => {
    await expect(
      getOptionalUser(request('Basic credentials')),
    ).rejects.toMatchObject({ status: 401, code: 'UNAUTHORIZED' });

    mockedCreateBearerClient.mockReturnValue(
      client(null, new Error('expired')) as never,
    );
    await expect(
      getOptionalUser(request('Bearer expired-token')),
    ).rejects.toMatchObject({ status: 401, code: 'UNAUTHORIZED' });
  });
});
