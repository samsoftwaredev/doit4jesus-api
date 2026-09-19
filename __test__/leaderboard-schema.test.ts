import { leaderboardQuerySchema } from '@/lib/schemas/leaderboard';

describe('leaderboard API schema', () => {
  it('defaults to the weekly global leaderboard', () => {
    expect(leaderboardQuerySchema.parse({})).toEqual({
      periodType: 'weekly',
      scopeType: 'global',
      scopeReference: 'global',
      limit: 50,
      offset: 0,
    });
  });

  it('accepts yearly periods and rejects unsupported period types', () => {
    expect(
      leaderboardQuerySchema.parse({ periodType: 'yearly' }),
    ).toMatchObject({ periodType: 'yearly' });

    for (const periodType of ['daily', 'monthly', 'season']) {
      expect(() => leaderboardQuerySchema.parse({ periodType })).toThrow();
    }
  });
});
