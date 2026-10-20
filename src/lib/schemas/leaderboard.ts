import { z } from 'zod';

export const leaderboardQuerySchema = z
  .object({
    periodType: z.enum(['weekly', 'yearly', 'lifetime']).default('weekly'),
    periodCode: z.string().trim().min(1).max(100).optional(),
    scopeType: z.enum(['global', 'country']).default('global'),
    scopeReference: z.string().trim().min(1).max(150).default('global'),
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).max(10_000).default(0),
  })
  .superRefine((query, context) => {
    if (query.scopeType === 'global' && query.periodType === 'yearly') {
      context.addIssue({
        code: 'custom',
        path: ['periodType'],
        message: 'Global leaderboards support weekly or lifetime periods.',
      });
    }

    if (query.scopeType === 'country' && query.periodType === 'lifetime') {
      context.addIssue({
        code: 'custom',
        path: ['periodType'],
        message: 'Country leaderboards support weekly or yearly periods.',
      });
    }

    if (
      query.periodType === 'lifetime' &&
      query.periodCode !== undefined &&
      query.periodCode !== 'lifetime'
    ) {
      context.addIssue({
        code: 'custom',
        path: ['periodCode'],
        message: 'The lifetime leaderboard period code must be lifetime.',
      });
    }
  });
