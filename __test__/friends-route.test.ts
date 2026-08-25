import { GET } from '../src/app/api/v1/me/friends/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, _init: unknown, meta?: unknown) => ({
    json: async () => ({ data, meta }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);

describe('GET /api/v1/me/friends', () => {
  it('includes the friend profile country code', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: [
        {
          friend_id: '11111111-1111-4111-8111-111111111111',
          display_name: 'Maria Santos',
          username: 'mariasantos',
          avatar_url: null,
          title: 'Prayer Champion',
          country_code: 'MX',
          total_xp: 920,
          current_level: 3,
          level_code: 'disciple',
          level_name: 'Disciple',
          rosary_total: 14,
          badge_count: 2,
          friends_since: '2026-08-01T12:00:00.000Z',
          rosary_streak: null,
        },
      ],
      error: null,
    });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await GET({
      url: 'http://localhost:3000/api/v1/me/friends',
    } as Request);

    expect(await response.json()).toMatchObject({
      data: [
        {
          id: '11111111-1111-4111-8111-111111111111',
          countryCode: 'MX',
        },
      ],
    });
  });
});
