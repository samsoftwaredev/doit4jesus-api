import { GET } from '../src/app/api/v1/locations/postal-codes/[postalCode]/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, init: ResponseInit) => ({
    status: 200,
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
  errorResponse: jest.fn(),
}));

const mockedRequireUser = jest.mocked(requireUser);

describe('GET /api/v1/locations/postal-codes/{postalCode}', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns map, city, timezone, and canonical diocese data', async () => {
    const postalResult = {
      data: {
        postal_code: '78701',
        primary_city: 'Austin',
        region_codes: ['TX'],
        latitude: 30.271129,
        longitude: -97.7437,
        timezone: 'America/Chicago',
        diocese_status: 'approximate_centroid',
      },
      error: null,
    };
    const citiesResult = {
      data: [
        {
          city_name: 'Austin',
          city_label: 'Austin city',
          region_code: 'TX',
          overlap_percent: 100,
          city_status: 'current_census_place',
          is_primary: true,
        },
      ],
      error: null,
    };
    const dioceseLinksResult = {
      data: [
        {
          diocese_id: 'c5000000-0000-4000-8000-000000000001',
          label: 'Austin',
          match_status: 'approximate_centroid',
        },
      ],
      error: null,
    };
    const diocesesResult = {
      data: [
        {
          id: 'c5000000-0000-4000-8000-000000000001',
          name: 'Diocese of Austin',
        },
      ],
      error: null,
    };

    const from = jest.fn((table: string) => {
      if (table === 'postal_codes') {
        return {
          select: jest.fn(() => ({
            eq: jest.fn(() => ({
              maybeSingle: jest.fn().mockResolvedValue(postalResult),
            })),
          })),
        };
      }
      if (table === 'postal_code_cities') {
        const secondOrder = jest.fn().mockResolvedValue(citiesResult);
        return {
          select: jest.fn(() => ({
            eq: jest.fn(() => ({
              order: jest.fn(() => ({ order: secondOrder })),
            })),
          })),
        };
      }
      if (table === 'postal_code_dioceses') {
        return {
          select: jest.fn(() => ({
            eq: jest.fn(() => ({
              order: jest.fn().mockResolvedValue(dioceseLinksResult),
            })),
          })),
        };
      }
      return {
        select: jest.fn(() => ({
          in: jest.fn().mockResolvedValue(diocesesResult),
        })),
      };
    });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
    } as never);

    const response = await GET(
      {
        url: 'http://localhost/api/v1/locations/postal-codes/78701',
      } as Request,
      { params: Promise.resolve({ postalCode: '78701' }) },
    );

    expect(response.status).toBe(200);
    expect(response.headers.get('Cache-Control')).toBe(
      'private, max-age=86400',
    );
    expect(await response.json()).toEqual({
      data: expect.objectContaining({
        postalCode: '78701',
        primaryCity: 'Austin',
        timezone: 'America/Chicago',
        cities: [expect.objectContaining({ name: 'Austin', isPrimary: true })],
        dioceses: [
          expect.objectContaining({
            id: 'c5000000-0000-4000-8000-000000000001',
            name: 'Diocese of Austin',
          }),
        ],
      }),
    });
  });
});
