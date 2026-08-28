import { z } from 'zod';

export const notificationPreferencesSchema = z
  .object({
    dailyRosaryReminder: z.boolean(),
    confessionReminder: z.boolean(),
    eucharisticAdoration: z.boolean(),
  })
  .strict();

export const updateNotificationPreferencesSchema = notificationPreferencesSchema
  .partial()
  .refine(
    (value) => Object.keys(value).length > 0,
    'At least one notification preference is required.',
  );
