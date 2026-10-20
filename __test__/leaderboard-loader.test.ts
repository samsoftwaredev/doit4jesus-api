import { loadLeaderboard } from '../src/lib/screen-data/loaders';

describe('screen-data global leaderboard loader', () => {
  it('returns Rosary-only entries and excludes zero-Rosary users', async () => {
    const userId = '11111111-1111-4111-8111-111111111111';
    const period = {
      id: '33333333-3333-4333-8333-333333333333',
      period_type: 'weekly',
      code: 'week-2026-W42',
      name: 'Week of 2026-10-19',
      starts_at: '2026-10-19T00:00:00.000Z',
      ends_at: '2026-10-26T00:00:00.000Z',
      status: 'active',
      finalized_at: null,
      created_at: '2026-10-19T00:00:00.000Z',
    };
    const entry = {
      period_id: period.id,
      user_id: userId,
      scope_type: 'global',
      scope_reference: 'global',
      points: 900,
      rank: 1,
      rosaries_count: 7,
      scripture_readings_count: 12,
      prayers_count: 20,
      updated_at: '2026-10-19T12:00:00.000Z',
    };

    const periodQuery: Record<string, jest.Mock> = {};
    for (const method of ['select', 'eq', 'lte', 'gt', 'order'] as const) {
      periodQuery[method] = jest.fn().mockReturnValue(periodQuery);
    }
    periodQuery.limit = jest
      .fn()
      .mockResolvedValue({ data: [period], error: null });

    const entriesQuery: Record<string, jest.Mock> = {};
    for (const method of ['select', 'eq', 'gt', 'order'] as const) {
      entriesQuery[method] = jest.fn().mockReturnValue(entriesQuery);
    }
    entriesQuery.range = jest
      .fn()
      .mockResolvedValue({ data: [entry], error: null, count: 1 });

    const currentUserQuery: Record<string, jest.Mock> = {};
    for (const method of ['select', 'eq', 'gt'] as const) {
      currentUserQuery[method] = jest.fn().mockReturnValue(currentUserQuery);
    }
    currentUserQuery.maybeSingle = jest
      .fn()
      .mockResolvedValue({ data: entry, error: null });

    const profilesQuery = {
      select: jest.fn(),
      in: jest.fn().mockResolvedValue({
        data: [
          {
            user_id: userId,
            display_name: 'Rosary Player',
            username: 'rosary_player',
            avatar_url: null,
            title: null,
            country_code: 'US',
            saint_avatar_id: null,
          },
        ],
        error: null,
      }),
    };
    profilesQuery.select.mockReturnValue(profilesQuery);

    const competitionFrom = jest
      .fn()
      .mockReturnValueOnce(periodQuery)
      .mockReturnValueOnce(entriesQuery)
      .mockReturnValueOnce(currentUserQuery);
    const context = {
      userId,
      supabase: {
        schema: jest.fn((schema: string) => ({
          from:
            schema === 'competition'
              ? competitionFrom
              : jest.fn().mockReturnValue(profilesQuery),
        })),
      },
    } as never;

    const result = await loadLeaderboard(context, 'weekly', 3);
    const data = result.data as {
      entries: Array<Record<string, unknown>>;
      currentUserEntry: Record<string, unknown>;
    };

    expect(entriesQuery.gt).toHaveBeenCalledWith('rosaries_count', 0);
    expect(currentUserQuery.gt).toHaveBeenCalledWith('rosaries_count', 0);
    expect(entriesQuery.order).toHaveBeenNthCalledWith(2, 'rosaries_count', {
      ascending: false,
    });
    expect(data.entries[0]).toMatchObject({
      rank: 1,
      rosaries_count: 7,
      isCurrentUser: true,
    });
    expect(data.entries[0]).not.toHaveProperty('points');
    expect(data.entries[0]).not.toHaveProperty('scripture_readings_count');
    expect(data.entries[0]).not.toHaveProperty('prayers_count');
    expect(data.currentUserEntry).not.toHaveProperty('points');
  });
});
