import { z } from 'zod';

import { countryCodeSchema } from '@/lib/schemas/profile';

export const eventIdSchema = z.uuid();

export const eventAudiences = [
  'all',
  'kids',
  'youth',
  'men',
  'women',
  'single',
  'married',
] as const;
export const eventStatuses = [
  'pending',
  'active',
  'inactive',
  'rejected',
] as const;

const nullableUrlSchema = z.url().max(2_000).nullable().optional();
const timestampSchema = z.iso.datetime({ offset: true });
const timezoneSchema = z
  .string()
  .trim()
  .min(1)
  .max(100)
  .refine((timezone) => {
    try {
      Intl.DateTimeFormat('en-US', { timeZone: timezone }).format();
      return true;
    } catch {
      return false;
    }
  }, 'timezone must be a valid IANA timezone.');

const commonEventShape = {
  title: z.string().trim().min(1).max(160),
  description: z.string().trim().min(1).max(10_000),
  imageUrl: nullableUrlSchema,
  eventUrl: nullableUrlSchema,
  timezone: timezoneSchema,
  startsAt: timestampSchema,
  endsAt: timestampSchema,
  lifespanDays: z.number().int().min(1).max(365),
  audiences: z
    .array(z.enum(eventAudiences))
    .min(1)
    .max(3)
    .refine((audiences) => new Set(audiences).size === audiences.length, {
      message: 'audiences must not contain duplicates.',
    }),
};

const physicalLocationShape = {
  locationName: z.string().trim().min(1).max(160),
  addressLine1: z.string().trim().min(1).max(200),
  addressLine2: z.string().trim().max(200).nullable().optional(),
  city: z.string().trim().min(1).max(120),
  regionName: z.string().trim().max(120).nullable().optional(),
  postalCode: z.string().trim().max(32).nullable().optional(),
  countryCode: countryCodeSchema,
};

export const createEventSchema = z
  .discriminatedUnion('eventType', [
    z
      .object({
        ...commonEventShape,
        eventType: z.literal('online'),
        onlineUrl: z.url().max(2_000),
      })
      .strict(),
    z
      .object({
        ...commonEventShape,
        ...physicalLocationShape,
        eventType: z.literal('physical'),
      })
      .strict(),
  ])
  .superRefine((event, context) => {
    if (new Date(event.endsAt) <= new Date(event.startsAt)) {
      context.addIssue({
        code: 'custom',
        path: ['endsAt'],
        message: 'endsAt must be after startsAt.',
      });
    }
  });

const offsetPageSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const eventFeedQuerySchema = offsetPageSchema.strict();

export const myEventsQuerySchema = offsetPageSchema
  .extend({
    status: z.enum([...eventStatuses, 'all']).default('all'),
  })
  .strict();

export const adminEventsQuerySchema = offsetPageSchema
  .extend({
    status: z.enum([...eventStatuses, 'all']).default('pending'),
  })
  .strict();

export const reviewEventSchema = z
  .object({
    decision: z.enum(['active', 'inactive', 'rejected']),
  })
  .strict();
