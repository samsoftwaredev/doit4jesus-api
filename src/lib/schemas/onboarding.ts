import { z } from 'zod';

import { notificationPreferencesSchema } from '@/lib/schemas/notification-preferences';
import { displayNameSchema } from '@/lib/schemas/profile';
import { usernameValueSchema } from '@/lib/schemas/username';

export const completeProfileSetupSchema = z
  .object({
    displayName: displayNameSchema,
    username: usernameValueSchema.nullable(),
    gender: z.enum(['male', 'female']),
    countryCode: z.string().trim().length(2).toUpperCase(),
    cityId: z.uuid(),
    notificationPreferences: notificationPreferencesSchema,
  })
  .strict();
