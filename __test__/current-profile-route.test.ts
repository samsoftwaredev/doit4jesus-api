import { DELETE, GET, PATCH } from '../src/app/api/v1/me/route';
import { ApiError } from '../src/lib/api/errors';
import { errorResponse } from '../src/lib/api/response';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown) => ({ json: async () => ({ data }) }),
  noContent: () => ({ status: 204 }),
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedErrorResponse = jest.mocked(errorResponse);
const userId = '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002';
const saintAvatarId = 'a1000000-0000-4000-8000-000000000002';

const profile = {
  user_id: userId,
  display_name: 'Test User',
  username: 'testuser',
  avatar_url: null,
  title: null,
  gender: 'male' as const,
  saint_avatar_id: saintAvatarId,
  preferred_language: 'en',
  timezone: 'America/Chicago',
  country_code: 'US',
  leaderboard_visibility: 'public' as const,
  prayer_map_visibility: 'aggregated' as const,
  profile_setup_completed_at: '2026-08-22T00:00:00.000Z',
  created_at: '2026-06-01T00:00:00.000Z',
  updated_at: '2026-08-22T00:00:00.000Z',
};

function countryQuery(country = { name: 'United States' }) {
  const query: Record<string, jest.Mock> = {};
  query.select = jest.fn().mockReturnValue(query);
  query.eq = jest.fn().mockReturnValue(query);
  query.maybeSingle = jest
    .fn()
    .mockResolvedValue({ data: country, error: null });
  return query;
}

describe('/api/v1/me', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects an unauthenticated account-deletion request', async () => {
    mockedRequireUser.mockRejectedValue(ApiError.unauthorized());

    await DELETE({ url: 'http://localhost/api/v1/me' } as Request);

    expect(mockedErrorResponse).toHaveBeenCalledWith(
      expect.objectContaining({ status: 401, code: 'UNAUTHORIZED' }),
      expect.anything(),
    );
  });

  it('returns persisted identity fields and the resolved country name', async () => {
    const profileQuery: Record<string, jest.Mock> = {};
    profileQuery.select = jest.fn().mockReturnValue(profileQuery);
    profileQuery.eq = jest.fn().mockReturnValue(profileQuery);
    profileQuery.single = jest
      .fn()
      .mockResolvedValue({ data: profile, error: null });
    const resolvedCountryQuery = countryQuery();
    const from = jest
      .fn()
      .mockReturnValueOnce(profileQuery)
      .mockReturnValueOnce(resolvedCountryQuery);
    const supabase = { schema: jest.fn(() => ({ from })) };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);

    const response = await GET({
      url: 'http://localhost/api/v1/me',
    } as Request);

    expect(await response.json()).toEqual({
      data: expect.objectContaining({
        gender: 'male',
        saintAvatarId,
        countryName: 'United States',
        profileSetup: {
          complete: true,
          missingFields: [],
          nextStep: null,
          completedAt: '2026-08-22T00:00:00.000Z',
        },
      }),
    });
    expect(from).toHaveBeenNthCalledWith(1, 'user_profiles');
    expect(from).toHaveBeenNthCalledWith(2, 'countries');
  });

  it('persists gender and an optional saint avatar through PATCH', async () => {
    const updatedProfile = {
      ...profile,
      gender: 'female' as const,
      saint_avatar_id: null,
    };
    const profileQuery: Record<string, jest.Mock> = {};
    profileQuery.update = jest.fn().mockReturnValue(profileQuery);
    profileQuery.eq = jest.fn().mockReturnValue(profileQuery);
    profileQuery.select = jest.fn().mockReturnValue(profileQuery);
    profileQuery.single = jest
      .fn()
      .mockResolvedValue({ data: updatedProfile, error: null });
    const from = jest
      .fn()
      .mockReturnValueOnce(profileQuery)
      .mockReturnValueOnce(countryQuery());
    const supabase = { schema: jest.fn(() => ({ from })) };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);

    const response = await PATCH({
      url: 'http://localhost/api/v1/me',
      headers: {
        get: (name: string) =>
          name === 'content-type' ? 'application/json' : null,
      },
      json: async () => ({ gender: 'female', saintAvatarId: null }),
    } as Request);

    expect(profileQuery.update).toHaveBeenCalledWith({
      gender: 'female',
      saint_avatar_id: null,
    });
    expect(await response.json()).toEqual({
      data: expect.objectContaining({
        gender: 'female',
        saintAvatarId: null,
      }),
    });
  });

  it('blocks a prohibited username before updating the profile', async () => {
    const from = jest.fn();
    const supabase = { schema: jest.fn(() => ({ from })) };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);
    mockedErrorResponse.mockClear();

    await PATCH({
      url: 'http://localhost/api/v1/me',
      headers: {
        get: (name: string) =>
          name === 'content-type' ? 'application/json' : null,
      },
      json: async () => ({ username: 'faithful_fuck' }),
    } as Request);

    expect(from).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 422,
        code: 'VALIDATION_ERROR',
        details: { reason: 'PROHIBITED_TERM' },
      }),
      expect.anything(),
    );
  });

  it('permanently deletes the current account and preserves its anonymous Rosary contribution', async () => {
    const rpc = jest.fn().mockResolvedValue({ data: null, error: null });
    const supabase = { schema: jest.fn(() => ({ rpc })) };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);

    const response = await DELETE({
      url: 'http://localhost/api/v1/me',
    } as Request);

    expect(rpc).toHaveBeenCalledWith('delete_user_account', {
      p_user_id: userId,
    });
    expect(response.status).toBe(204);
  });

  it('returns a safe error when account deletion fails', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: null,
      error: { code: 'XX000', message: 'internal details' },
    });
    const supabase = { schema: jest.fn(() => ({ rpc })) };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);
    const consoleError = jest
      .spyOn(console, 'error')
      .mockImplementation(() => undefined);

    await DELETE({ url: 'http://localhost/api/v1/me' } as Request);

    consoleError.mockRestore();

    expect(mockedErrorResponse).toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
    );
  });
});
