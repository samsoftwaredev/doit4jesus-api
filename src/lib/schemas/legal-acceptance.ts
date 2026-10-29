import { z } from 'zod';

export const legalAcceptanceSchema = z
  .object({
    locale: z.enum(['en', 'es']),
    adultConfirmed: z.literal(true),
    usResidentConfirmed: z.literal(true),
  })
  .strict();
