import { z } from 'zod';

import { countryCodeSchema } from '@/lib/schemas/profile';

export const recordActivitySchema = z
  .object({
    activityCode: z
      .string()
      .trim()
      .min(1)
      .max(50)
      .transform((value) => value.toUpperCase()),
    occurredAt: z.iso.datetime({ offset: true }),
    completedAt: z.iso.datetime({ offset: true }).nullable().optional(),
    durationSeconds: z.number().int().min(0).max(86_400).nullable().optional(),
    quantity: z.number().int().min(1).max(100).default(1),
    countryCode: countryCodeSchema.nullable().optional(),
    metadata: z.record(z.string(), z.unknown()).default({}),
  })
  .strict();
