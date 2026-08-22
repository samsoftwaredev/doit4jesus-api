import { GET, PATCH } from '../src/app/api/v1/me/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown) => ({ json: async () => ({ data }) }),
}));

const mockedRequireUser = jest.mocked(requireUser);
const userId = '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002';
const cityId = 'e0000000-0000-4000-8000-000000000001';
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
  city_id: cityId,
  country_code: 'US',
  leaderboard_visibility: 'public' as const,
  prayer_map_visibility: 'aggregated' as const,
  created_at: '2026-06-01T00:00:00.000Z',
  updated_at: '2026-08-22T00:00:00.000Z',
};

function cityQuery(city = { name: 'Chicago', region_name: 'Illinois' }) {
  const query: Record<string, jest.Mock> = {};
  query.select = jest.fn().mockReturnValue(query);
  query.eq = jest.fn().mockReturnValue(query);
  query.maybeSingle = jest.fn().mockResolvedValue({ data: city, error: null });
  return query;
}

describe('/api/v1/me', () => {
  it('returns persisted identity fields and the resolved city name and state', async () => {
    const profileQuery: Record<string, jest.Mock> = {};
    profileQuery.select = jest.fn().mockReturnValue(profileQuery);
    profileQuery.eq = jest.fn().mockReturnValue(profileQuery);
    profileQuery.single = jest
      .fn()
      .mockResolvedValue({ data: profile, error: null });
    const resolvedCityQuery = cityQuery();
    const from = jest
      .fn()
      .mockReturnValueOnce(profileQuery)
      .mockReturnValueOnce(resolvedCityQuery);
    const supabase = { schema: jest.fn(() => ({ from })) };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);

    const response = await GET({
      url: 'http://localhost/api/v1/me',
    } as Request);

    expect(await response.json()).toEqual({
      data: expect.objectContaining({
        gender: 'male',
        saintAvatarId,
        cityName: 'Chicago',
        state: 'Illinois',
      }),
    });
    expect(from).toHaveBeenNthCalledWith(1, 'user_profiles');
    expect(from).toHaveBeenNthCalledWith(2, 'cities');
  });

  it('returns null cityName and state when no city is stored', async () => {
    const profileQuery: Record<string, jest.Mock> = {};
    profileQuery.select = jest.fn().mockReturnValue(profileQuery);
    profileQuery.eq = jest.fn().mockReturnValue(profileQuery);
    profileQuery.single = jest.fn().mockResolvedValue({
      data: { ...profile, city_id: null },
      error: null,
    });
    const from = jest.fn().mockReturnValue(profileQuery);
    const supabase = { schema: jest.fn(() => ({ from })) };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);

    const response = await GET({
      url: 'http://localhost/api/v1/me',
    } as Request);

    expect(await response.json()).toEqual({
      data: expect.objectContaining({
        cityId: null,
        cityName: null,
        state: null,
      }),
    });
    expect(from).toHaveBeenCalledTimes(1);
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
    const resolvedCityQuery = cityQuery();
    const from = jest
      .fn()
      .mockReturnValueOnce(profileQuery)
      .mockReturnValueOnce(resolvedCityQuery);
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
        cityName: 'Chicago',
        state: 'Illinois',
      }),
    });
  });
});
