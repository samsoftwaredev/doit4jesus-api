import { z } from 'zod';

const paginationSchema = {
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).max(10_000).default(0),
};

export const countrySearchQuerySchema = z.object({
  q: z.string().trim().min(1).max(120).optional(),
  ...paginationSchema,
});

export const citySearchQuerySchema = z.object({
  countryCode: z.string().trim().length(2).toUpperCase(),
  q: z
    .string()
    .trim()
    .min(2, 'A city search must contain at least 2 characters.')
    .max(150),
  ...paginationSchema,
});
