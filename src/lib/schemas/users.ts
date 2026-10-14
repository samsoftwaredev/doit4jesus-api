import { z } from 'zod';

export const accountUserIdSchema = z.uuid();

export const adminUserSearchQuerySchema = z.object({
  q: z.string().trim().min(2).max(320),
  limit: z.coerce.number().int().min(1).max(20).default(20),
});

export const adminUserDeletionPreviewQuerySchema = z.object({
  section: z
    .enum(['account', 'community', 'progress', 'prayer'])
    .default('account'),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export const userSearchQuerySchema = z.object({
  q: z
    .string()
    .trim()
    .min(4, 'A username search must contain at least 4 characters.')
    .max(30)
    .regex(
      /^[a-zA-Z0-9_]+$/,
      'Username searches may contain letters, numbers, and underscores.',
    ),
  limit: z.coerce.number().int().min(1).max(20).default(20),
  offset: z.coerce.number().int().min(0).max(10_000).default(0),
});
