import { z } from 'zod';

import { usernameValueSchema } from '@/lib/schemas/username';

function isValidTimeZone(value: string) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value }).format();
    return true;
  } catch {
    return false;
  }
}

export function normalizeDisplayName(value: string) {
  return value.trim().replace(/\s+/g, ' ');
}

export const displayNameSchema = z
  .string()
  .transform(normalizeDisplayName)
  .pipe(z.string().min(1).max(80));

export const updateProfileSchema = z
  .object({
    displayName: displayNameSchema.optional(),
    username: usernameValueSchema.nullable().optional(),
    avatarUrl: z.url().nullable().optional(),
    title: z.string().trim().max(100).nullable().optional(),
    gender: z.enum(['male', 'female']).optional(),
    saintAvatarId: z.uuid().nullable().optional(),
    preferredLanguage: z.string().trim().min(2).max(10).optional(),
    timezone: z
      .string()
      .trim()
      .min(1)
      .max(100)
      .refine(isValidTimeZone, 'Invalid IANA timezone.')
      .optional(),
    cityId: z.uuid().nullable().optional(),
    countryCode: z
      .string()
      .trim()
      .length(2)
      .toUpperCase()
      .nullable()
      .optional(),
    leaderboardVisibility: z.enum(['public', 'friends', 'private']).optional(),
    prayerMapVisibility: z.enum(['aggregated', 'hidden']).optional(),
  })
  .strict()
  .refine(
    (value) => Object.keys(value).length > 0,
    'At least one profile field is required.',
  );
