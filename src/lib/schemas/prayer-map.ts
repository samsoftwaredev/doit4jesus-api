import { z } from 'zod';

import { countryCodeSchema } from '@/lib/schemas/profile';

export const prayerMapQuerySchema = z.object({
  from: z.iso.datetime({ offset: true }),
  to: z.iso.datetime({ offset: true }),
  countryCode: countryCodeSchema.optional(),
});
