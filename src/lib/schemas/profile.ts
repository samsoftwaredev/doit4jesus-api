import { z } from 'zod'

function isValidTimeZone(value: string) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value }).format()
    return true
  } catch {
    return false
  }
}

export const updateProfileSchema = z
  .object({
    displayName: z.string().trim().min(2).max(80).optional(),
    username: z
      .string()
      .trim()
      .min(3)
      .max(30)
      .regex(/^[a-zA-Z0-9_]+$/, 'Username may contain letters, numbers, and underscores.')
      .nullable()
      .optional(),
    avatarUrl: z.url().nullable().optional(),
    title: z.string().trim().max(100).nullable().optional(),
    preferredLanguage: z.string().trim().min(2).max(10).optional(),
    timezone: z.string().trim().min(1).max(100).refine(isValidTimeZone, 'Invalid IANA timezone.').optional(),
    cityId: z.uuid().nullable().optional(),
    countryCode: z.string().trim().length(2).toUpperCase().nullable().optional(),
    leaderboardVisibility: z.enum(['public', 'friends', 'private']).optional(),
    prayerMapVisibility: z.enum(['aggregated', 'hidden']).optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, 'At least one profile field is required.')
