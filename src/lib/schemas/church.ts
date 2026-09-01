import { z } from 'zod';

import { countryCodeSchema } from '@/lib/schemas/profile';

export const churchIdSchema = z.uuid();

export const churchServiceTypes = ['mass', 'confession', 'adoration'] as const;
export const weekdayCodes = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const;

const localTimeSchema = z
  .string()
  .regex(
    /^(?:[01]\d|2[0-3]):[0-5]\d$/,
    'Time must use HH:MM (24-hour) format.',
  );

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

export const churchServiceTimeSchema = z.object({
  serviceType: z.enum(churchServiceTypes),
  weekday: z.enum(weekdayCodes),
  startTime: localTimeSchema,
  endTime: localTimeSchema.nullable().optional(),
});

const churchDetailsSchema = z.object({
  dioceseId: z.uuid().nullable().optional(),
  name: z.string().trim().min(2).max(200),
  addressLine1: z.string().trim().min(2).max(200),
  addressLine2: z.string().trim().max(200).nullable().optional(),
  city: z.string().trim().min(1).max(150),
  regionName: z.string().trim().max(150).nullable().optional(),
  postalCode: z.string().trim().max(32).nullable().optional(),
  countryCode: countryCodeSchema,
  timezone: timezoneSchema,
  latitude: z.number().finite().gte(-90).lte(90),
  longitude: z.number().finite().gte(-180).lte(180),
});

const requestNotesSchema = z.string().trim().max(2_000).nullable().optional();

export const createChurchChangeRequestSchema = z.discriminatedUnion(
  'requestType',
  [
    z.object({
      requestType: z.literal('createChurch'),
      church: churchDetailsSchema,
      serviceTimes: z.array(churchServiceTimeSchema).min(1).max(100),
      notes: requestNotesSchema,
    }),
    z.object({
      requestType: z.literal('scheduleUpdate'),
      churchId: z.uuid(),
      serviceTimes: z.array(churchServiceTimeSchema).min(1).max(100),
      notes: requestNotesSchema,
    }),
  ],
);

export const churchSearchQuerySchema = z
  .object({
    countryCode: countryCodeSchema.optional(),
    city: z.string().trim().min(1).max(150).optional(),
    diocese: z.string().trim().min(1).max(160).optional(),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .refine(
    (query) => Boolean(query.countryCode || query.city || query.diocese),
    'At least one of countryCode, city, or diocese is required.',
  );

export const createUserChurchLinkSchema = z.object({
  churchId: z.uuid(),
  isPrimary: z.boolean().default(false),
});

export const setPrimaryChurchSchema = z.object({
  isPrimary: z.literal(true),
});

export const churchChangeRequestQuerySchema = z.object({
  status: z.enum(['pending', 'approved', 'rejected', 'all']).default('all'),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0),
});

export const reviewChurchChangeRequestSchema = z.object({
  decision: z.enum(['approved', 'rejected']),
  rejectionReason: z.string().trim().max(2_000).nullable().optional(),
});
