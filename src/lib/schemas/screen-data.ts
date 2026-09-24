import { z } from 'zod';

export const screenDataQuerySchema = z
  .object({
    screen: z.enum(['home', 'prayer', 'community']),
    country: z.string().trim().min(1).max(10).optional(),
    diocese: z.string().trim().min(1).max(120).optional(),
    locale: z.string().trim().min(1).max(35).optional(),
    selectedMonth: z.coerce.number().int().min(1).max(12).optional(),
    selectedYear: z.coerce.number().int().min(1).max(9998).optional(),
  })
  .strict();

export type ScreenDataQuery = z.infer<typeof screenDataQuerySchema>;
