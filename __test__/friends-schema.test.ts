import {
  friendRequestsQuerySchema,
  friendsLeaderboardQuerySchema,
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
  });
});
