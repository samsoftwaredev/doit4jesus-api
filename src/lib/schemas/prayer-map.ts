import { z } from 'zod'

export const prayerMapQuerySchema = z.object({
  level: z.enum(['country', 'city']).default('country'),
  from: z.iso.datetime({ offset: true }),
  to: z.iso.datetime({ offset: true }),
  countryCode: z.string().trim().length(2).toUpperCase().optional(),
})
