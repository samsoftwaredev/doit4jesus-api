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

  it('accepts the supported period and scope combinations', () => {
    expect(
      leaderboardQuerySchema.parse({ periodType: 'lifetime' }),
    ).toMatchObject({ periodType: 'lifetime', scopeType: 'global' });
    expect(
      leaderboardQuerySchema.parse({
        periodType: 'yearly',
        scopeType: 'country',
        scopeReference: 'US',
      }),
    ).toMatchObject({ periodType: 'yearly', scopeType: 'country' });

    expect(() =>
      leaderboardQuerySchema.parse({ periodType: 'yearly' }),
    ).toThrow();
    expect(() =>
      leaderboardQuerySchema.parse({
        periodType: 'lifetime',
        scopeType: 'country',
        scopeReference: 'US',
      }),
    ).toThrow();
  });

  it('allows only the singleton lifetime period code', () => {
    expect(
      leaderboardQuerySchema.parse({
        periodType: 'lifetime',
        periodCode: 'lifetime',
      }),
    ).toMatchObject({ periodCode: 'lifetime' });

    expect(() =>
      leaderboardQuerySchema.parse({
        periodType: 'lifetime',
        periodCode: 'year-2026',
      }),
    ).toThrow();
  });

  it('rejects unsupported period types', () => {
    for (const periodType of ['daily', 'monthly', 'season']) {
      expect(() => leaderboardQuerySchema.parse({ periodType })).toThrow();
    }
  });
});
