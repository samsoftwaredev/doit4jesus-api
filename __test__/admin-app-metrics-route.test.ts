import { GET } from '../src/app/api/v1/admin/app-metrics/route';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);

describe('GET /api/v1/admin/app-metrics', () => {
  it('returns aggregate metrics only after administrator authorization', async () => {
    const metrics = {
      totalUsers: 531,
      dailyActiveUsers: 11,
      weeklyActiveUsers: 46,
      monthlyActiveUsers: 171,
      signups7d: 0,
      signups30d: 0,
      retentionD1: 0,
      retentionD7: 0,
      retentionD30: 0,
      signupToActiveRate: 32.2,
      onboardingCompletionRate: 78.4,
      firstPracticeWithin7dRate: 44.6,
      churnRate: 67.8,
      rosaryCompletionRate: 27.3,
      trends: [
        {
          date: '2026-08-29',
          signups: 4,
          newlyActiveUsers: 2,
          dailyActiveUsers: 11,
          rosariesStarted: 7,
          rosariesCompleted: 5,
        },
      ],
    };
    const rpc = jest.fn().mockResolvedValue({ data: metrics, error: null });
    mockedRequireAdmin.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await GET({
      url: 'http://localhost:3000/api/v1/admin/app-metrics',
    } as Request);

    expect(mockedRequireAdmin).toHaveBeenCalledTimes(1);
    expect(rpc).toHaveBeenCalledWith('get_admin_app_metrics');
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(await response.json()).toEqual({ data: metrics });
  });
});
