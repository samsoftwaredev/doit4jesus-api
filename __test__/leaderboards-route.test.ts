import { GET } from '../src/app/api/v1/leaderboards/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, _init: unknown, meta?: unknown) => ({
    json: async () => (meta ? { data, meta } : { data }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);

describe('GET /api/v1/leaderboards', () => {
  it('returns the current user entry when it is outside the requested page', async () => {
    const currentUserId = '11111111-1111-4111-8111-111111111111';
    const otherUserId = '22222222-2222-4222-8222-222222222222';
    const period = {
      id: '33333333-3333-4333-8333-333333333333',
      period_type: 'weekly',
      code: '2026-W33',
      name: 'Week 33',
      starts_at: '2026-08-10T00:00:00.000Z',
      ends_at: '2026-08-17T00:00:00.000Z',
      status: 'active',
      finalized_at: null,
      created_at: '2026-08-10T00:00:00.000Z',
    };
    const pageEntry = {
      period_id: period.id,
      user_id: otherUserId,
      scope_type: 'global',
      scope_reference: 'global',
      points: 90,
      rank: 1,
      rosaries_count: 3,
      scripture_readings_count: 2,
      prayers_count: 1,
      updated_at: '2026-08-16T00:00:00.000Z',
    };
    const currentUserEntry = {
      ...pageEntry,
      user_id: currentUserId,
      points: 5,
      rank: 99,
    };

    const periodQuery: Record<string, jest.Mock> = {};
    periodQuery.select = jest.fn().mockReturnValue(periodQuery);
    periodQuery.eq = jest.fn().mockReturnValue(periodQuery);
    periodQuery.in = jest.fn().mockReturnValue(periodQuery);
    periodQuery.order = jest.fn().mockReturnValue(periodQuery);
    periodQuery.limit = jest.fn().mockResolvedValue({ data: [period], error: null });

    const pageEntriesQuery: Record<string, jest.Mock> = {};
    pageEntriesQuery.select = jest.fn().mockReturnValue(pageEntriesQuery);
    pageEntriesQuery.eq = jest.fn().mockReturnValue(pageEntriesQuery);
    pageEntriesQuery.order = jest.fn().mockReturnValue(pageEntriesQuery);
    pageEntriesQuery.range = jest
      .fn()
      .mockResolvedValue({ data: [pageEntry], error: null, count: 100 });

    const currentUserEntryQuery: Record<string, jest.Mock> = {};
    currentUserEntryQuery.select = jest.fn().mockReturnValue(currentUserEntryQuery);
    currentUserEntryQuery.eq = jest.fn().mockReturnValue(currentUserEntryQuery);
    currentUserEntryQuery.maybeSingle = jest
      .fn()
      .mockResolvedValue({ data: currentUserEntry, error: null });

    const profilesQuery: Record<string, jest.Mock> = {};
    profilesQuery.select = jest.fn().mockReturnValue(profilesQuery);
    profilesQuery.in = jest.fn().mockResolvedValue({
      data: [
        {
          user_id: otherUserId,
          display_name: 'Page Player',
          username: 'pageplayer',
          avatar_url: null,
          title: null,
        },
        {
          user_id: currentUserId,
          display_name: 'Current Player',
          username: 'currentplayer',
          avatar_url: null,
          title: null,
        },
      ],
      error: null,
    });

    const competitionFrom = jest
      .fn()
      .mockReturnValueOnce(periodQuery)
      .mockReturnValueOnce(pageEntriesQuery)
      .mockReturnValueOnce(currentUserEntryQuery);
    const appFrom = jest.fn().mockReturnValue(profilesQuery);
    const supabase = {
      schema: jest.fn((schema: string) => ({
        from: schema === 'competition' ? competitionFrom : appFrom,
      })),
    };

    mockedRequireUser.mockResolvedValue({ supabase, userId: currentUserId } as never);

    const response = await GET({
      url: 'http://localhost:3000/api/v1/leaderboards?limit=1&offset=0',
    } as Request);
    const body = await response.json();

    expect(body).toMatchObject({
      data: {
        period,
        entries: [
          {
            ...pageEntry,
            isCurrentUser: false,
            profile: { user_id: otherUserId, display_name: 'Page Player' },
          },
        ],
        currentUserEntry: {
          ...currentUserEntry,
          isCurrentUser: true,
          profile: { user_id: currentUserId, display_name: 'Current Player' },
        },
      },
      meta: { total: 100, limit: 1, offset: 0 },
    });
    expect(profilesQuery.in).toHaveBeenCalledWith('user_id', [otherUserId, currentUserId]);
  });
});
