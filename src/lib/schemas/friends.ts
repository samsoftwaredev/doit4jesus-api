import { z } from 'zod';

export const friendIdSchema = z.uuid();
export const friendRequestIdSchema = z.uuid();

export const sendFriendRequestSchema = z.object({
  username: z.string().trim().min(3).max(30),
});

export const reviewFriendRequestSchema = z.object({
  decision: z.enum(['accepted', 'rejected']),
});

const pagingSchema = {
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).max(10_000).default(0),
};

export const friendRequestsQuerySchema = z.object({
  direction: z.enum(['incoming', 'outgoing', 'all']).default('incoming'),
  status: z
    .enum(['pending', 'accepted', 'rejected', 'cancelled', 'all'])
    .default('pending'),
  ...pagingSchema,
});

export const friendsQuerySchema = z.object({
  ...pagingSchema,
  include: z.enum(['rosaryStreak']).optional(),
});

export const friendsLeaderboardQuerySchema = z.object({
  periodType: z
    .enum(['daily', 'weekly', 'monthly', 'yearly', 'season'])
    .default('weekly'),
  periodCode: z.string().trim().min(1).max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).max(10_000).default(0),
});
