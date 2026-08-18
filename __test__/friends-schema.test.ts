import {
  friendDetailsQuerySchema,
  friendRequestsQuerySchema,
  friendsComparisonQuerySchema,
  friendsLeaderboardQuerySchema,
  friendsQuerySchema,
  reviewFriendRequestSchema,
  sendFriendRequestSchema,
} from '@/lib/schemas/friends';

describe('friend API schemas', () => {
  it('accepts a username-only friend request', () => {
    expect(sendFriendRequestSchema.parse({ username: 'JoHnPaUl' })).toEqual({
      username: 'JoHnPaUl',
    });
  });

  it('only accepts friend-request decisions supported by the API', () => {
    expect(reviewFriendRequestSchema.parse({ decision: 'accepted' })).toEqual({
      decision: 'accepted',
    });
    expect(() =>
      reviewFriendRequestSchema.parse({ decision: 'cancelled' }),
    ).toThrow();
  });

  it('defaults friend-request and friends-leaderboard queries', () => {
    expect(friendRequestsQuerySchema.parse({})).toEqual({
      direction: 'incoming',
      status: 'pending',
      limit: 20,
      offset: 0,
    });
    expect(friendsLeaderboardQuerySchema.parse({})).toEqual({
      periodType: 'weekly',
      limit: 50,
      offset: 0,
    });
    expect(friendsComparisonQuerySchema.parse({})).toEqual({
      periodType: 'weekly',
      limit: 50,
      offset: 0,
    });
  });

  it('allows requesting Rosary streaks on friend cards', () => {
    expect(friendsQuerySchema.parse({ include: 'rosaryStreak' })).toEqual({
      include: 'rosaryStreak',
      limit: 20,
      offset: 0,
    });
    expect(() => friendsQuerySchema.parse({ include: 'badges' })).toThrow();
  });

  it('allows requesting a Rosary streak on a friend detail', () => {
    expect(friendDetailsQuerySchema.parse({ include: 'rosaryStreak' })).toEqual({
      include: 'rosaryStreak',
    });
    expect(friendDetailsQuerySchema.parse({})).toEqual({});
    expect(() => friendDetailsQuerySchema.parse({ include: 'badges' })).toThrow();
  });
});
