import { z } from 'zod';

export const prayerIntentionIdSchema = z.uuid();

export const prayerIntentionStatuses = [
  'pending',
  'visible',
  'rejected',
] as const;

export const prayerIntentionSymbols = [
  'candle',
  'cross',
  'dove',
  'olive_branch',
] as const;

export const createPrayerIntentionSchema = z
  .object({
    title: z.string().trim().min(1).max(120),
    description: z.string().trim().min(1).max(250),
    symbol: z.enum(prayerIntentionSymbols).nullable().optional(),
  })
  .strict();

const offsetPageSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const prayerIntentionFeedQuerySchema = offsetPageSchema.strict();

export const prayerIntentionPrayersQuerySchema = offsetPageSchema.strict();

export const myPrayerIntentionsQuerySchema = offsetPageSchema
  .extend({
    status: z.enum([...prayerIntentionStatuses, 'all']).default('all'),
  })
  .strict();

export const adminPrayerIntentionsQuerySchema = offsetPageSchema
  .extend({
    status: z.enum([...prayerIntentionStatuses, 'all']).default('pending'),
    createdAt: z.iso.date().optional(),
  })
  .strict();

export const reviewPrayerIntentionSchema = z
  .object({
    decision: z.enum(['visible', 'rejected']),
  })
  .strict();
