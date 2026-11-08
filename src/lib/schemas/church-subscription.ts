import { z } from 'zod';

import {
  churchServiceTimeSchema,
  churchServiceTypes,
  weekdayCodes,
} from '@/lib/schemas/church';

const uniqueServiceTypesSchema = z
  .array(z.enum(churchServiceTypes))
  .min(1)
  .max(churchServiceTypes.length)
  .refine(
    (items) => new Set(items).size === items.length,
    'Service types must be unique.',
  );

const uniqueWeekdaysSchema = z
  .array(z.enum(weekdayCodes))
  .min(1)
  .max(weekdayCodes.length)
  .refine(
    (items) => new Set(items).size === items.length,
    'Notification weekdays must be unique.',
  );

export const createChurchSubscriptionSchema = z
  .object({
    churchId: z.uuid(),
    serviceTypes: uniqueServiceTypesSchema,
    notificationWeekdays: uniqueWeekdaysSchema,
  })
  .strict();

export const updateChurchSubscriptionSchema = z
  .object({
    serviceTypes: uniqueServiceTypesSchema.optional(),
    notificationWeekdays: uniqueWeekdaysSchema.optional(),
  })
  .strict()
  .refine(
    (input) => Object.keys(input).length > 0,
    'At least one subscription preference is required.',
  );

export const upcomingChurchServicesQuerySchema = z
  .object({
    from: z.iso.datetime({ offset: true }).optional(),
    days: z.coerce.number().int().min(1).max(31).default(7),
    churchId: z.uuid().optional(),
    serviceType: z.enum(churchServiceTypes).optional(),
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();

const adminChurchCorrectionSchema = z
  .object({
    dioceseId: z.uuid().nullable().optional(),
    name: z.string().trim().min(2).max(200).optional(),
    addressLine1: z.string().trim().min(2).max(200).optional(),
    addressLine2: z.string().trim().max(200).nullable().optional(),
    city: z.string().trim().min(1).max(150).optional(),
    regionName: z.string().trim().max(150).nullable().optional(),
    postalCode: z.string().trim().max(32).nullable().optional(),
    countryCode: z
      .string()
      .trim()
      .toUpperCase()
      .regex(/^[A-Z]{2}$/)
      .optional(),
    timezone: z
      .string()
      .trim()
      .min(1)
      .max(100)
      .refine((value) => {
        try {
          Intl.DateTimeFormat('en-US', { timeZone: value }).format();
          return true;
        } catch {
          return false;
        }
      }, 'timezone must be a valid IANA timezone.')
      .optional(),
    latitude: z.number().finite().gte(-90).lte(90).optional(),
    longitude: z.number().finite().gte(-180).lte(180).optional(),
  })
  .strict();

export const reviewChurchScheduleSchema = z.discriminatedUnion('decision', [
  z
    .object({
      decision: z.literal('verified'),
      church: adminChurchCorrectionSchema.optional(),
      serviceTimes: z
        .array(churchServiceTimeSchema)
        .min(3)
        .max(100)
        .refine(
          (serviceTimes) =>
            churchServiceTypes.every((serviceType) =>
              serviceTimes.some((item) => item.serviceType === serviceType),
            ),
          'Mass, confession, and adoration must each have at least one service time.',
        ),
      reason: z.string().trim().max(2_000).nullable().optional(),
    })
    .strict(),
  z
    .object({
      decision: z.literal('closed'),
      reason: z.string().trim().min(1).max(2_000),
    })
    .strict(),
]);

export const churchScheduleReviewQuerySchema = z
  .object({
    status: z.enum(['pending', 'completed', 'all']).default('pending'),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();
