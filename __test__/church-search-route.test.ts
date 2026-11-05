import { GET } from '../src/app/api/v1/churches/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, _init: ResponseInit, meta: unknown) => ({
    status: 200,
    json: async () => ({ data, meta }),
  }),
  errorResponse: jest.fn(),
}));

const mockedRequireUser = jest.mocked(requireUser);

describe('GET /api/v1/churches', () => {
  beforeEach(() => jest.clearAllMocks());

  it('searches from a ZIP centroid and returns distance and verification state', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: [
        {
          id: 'c6000000-0000-4000-8000-000000000001',
          name: 'St. Mary Cathedral',
          address_line_1: '203 E 10th St',
          address_line_2: null,
          city: 'Austin',
          region_name: 'Texas',
          postal_code: '78701',
          country_code: 'US',
          diocese_id: 'c5000000-0000-4000-8000-000000000001',
          diocese_name: 'Diocese of Austin',
          timezone: 'America/Chicago',
          latitude: 30.270833,
          longitude: -97.741389,
          distance_miles: 0.2,
          directory_verification_status: 'verified',
          schedule_status: 'verified',
        },
      ],
      error: null,
    });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await GET({
      url: 'http://localhost/api/v1/churches?postalCode=78701&radiusMiles=10&q=Mary&limit=20&offset=0',
    } as Request);

    expect(rpc).toHaveBeenCalledWith(
      'search_churches_v2',
      expect.objectContaining({
        p_postal_code: '78701',
        p_radius_miles: 10,
        p_query: 'Mary',
        p_limit: 21,
      }),
    );
    await expect(response.json()).resolves.toEqual({
      data: [
        expect.objectContaining({
          name: 'St. Mary Cathedral',
          distanceMiles: 0.2,
          directoryVerificationStatus: 'verified',
          scheduleStatus: 'verified',
        }),
      ],
      meta: expect.objectContaining({ hasMore: false }),
    });
  });
});
