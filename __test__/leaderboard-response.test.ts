import { toLeaderboardResponseEntry } from '../src/lib/leaderboards/response';

const entry = {
  period_id: '33333333-3333-4333-8333-333333333333',
  user_id: '11111111-1111-4111-8111-111111111111',
  scope_type: 'global' as const,
  scope_reference: 'global',
  points: 500,
  rank: 1,
  rosaries_count: 5,
  scripture_readings_count: 4,
  prayers_count: 9,
  updated_at: '2026-10-19T12:00:00.000Z',
};

const profile = {
  user_id: entry.user_id,
  display_name: 'Rosary Player',
  username: 'rosary_player',
  avatar_url: null,
  title: null,
  country_code: 'US',
  saint_avatar_id: null,
};

describe('leaderboard response entries', () => {
  it('exposes only Rosary ranking fields for global entries', () => {
    const result = toLeaderboardResponseEntry(
      entry,
      profile,
      entry.user_id,
      true,
    );

    expect(result).toMatchObject({
      rank: 1,
      rosaries_count: 5,
      isCurrentUser: true,
      profile: { display_name: 'Rosary Player' },
    });
    expect(result).not.toHaveProperty('points');
    expect(result).not.toHaveProperty('scripture_readings_count');
    expect(result).not.toHaveProperty('prayers_count');
  });

  it('preserves point and activity fields for country entries', () => {
    const result = toLeaderboardResponseEntry(
      {
        ...entry,
        scope_type: 'country',
        scope_reference: 'US',
      },
      profile,
      entry.user_id,
      false,
    );

    expect(result).toMatchObject({
      points: 500,
      scripture_readings_count: 4,
      prayers_count: 9,
      rosaries_count: 5,
    });
  });
});
