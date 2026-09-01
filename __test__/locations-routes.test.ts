import { GET as getCountries } from '../src/app/api/v1/locations/countries/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit, meta?: unknown) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data, meta }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);

describe('location autocomplete routes', () => {
  it('lists matching countries and reports whether another page exists', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: [
        {
          code: 'US',
          name: 'United States',
          latitude: 39.8283,
          longitude: -98.5795,
        },
        {
          code: 'UM',
          name: 'United States Minor Outlying Islands',
          latitude: 19.2823,
          longitude: 166.647,
        },
      ],
      error: null,
    });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await getCountries({
      url: 'http://localhost/api/v1/locations/countries?q=united&limit=1',
    } as Request);

    expect(rpc).toHaveBeenCalledWith('search_countries', {
      p_query: 'united',
      p_limit: 2,
      p_offset: 0,
    });
    expect(await response.json()).toEqual({
      data: [
        {
          code: 'US',
          name: 'United States',
          latitude: 39.8283,
          longitude: -98.5795,
        },
      ],
      meta: {
        limit: 1,
        offset: 0,
        hasMore: true,
        nextOffset: 1,
      },
    });
  });
});
