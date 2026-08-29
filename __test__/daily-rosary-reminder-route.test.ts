import { GET } from '../src/app/api/v1/me/rosary/reminder/route';
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

describe('GET /api/v1/me/rosary/reminder', () => {
  it('returns the backend-authoritative reminder snapshot without caching it', async () => {
    const snapshot = {
      serverNow: '2026-08-29T18:14:00.000Z',
      timezone: 'America/Chicago',
      todayRosaryCompleted: false,
      deadlineAt: '2026-08-30T05:00:00.000Z',
      nextRosaryAvailableAt: null,
      gracePeriodEndsAt: null,
      streak: { current: 28, longest: 42, status: 'at-risk' },
    };
    const rpc = jest.fn().mockResolvedValue({ data: snapshot, error: null });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await GET({
      url: 'http://localhost:3000/api/v1/me/rosary/reminder',
    } as Request);

    expect(rpc).toHaveBeenCalledWith('get_my_daily_rosary_reminder');
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(await response.json()).toEqual({ data: snapshot });
  });
});
