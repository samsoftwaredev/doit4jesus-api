import { z } from 'zod';

export const leaderboardQuerySchema = z.object({
  periodType: z
    .enum(['daily', 'weekly', 'monthly', 'yearly', 'season'])
    .default('weekly'),
  periodCode: z.string().trim().min(1).max(100).optional(),
  scopeType: z.enum(['global', 'country']).default('global'),
  scopeReference: z.string().trim().min(1).max(150).default('global'),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).max(10_000).default(0),
});
