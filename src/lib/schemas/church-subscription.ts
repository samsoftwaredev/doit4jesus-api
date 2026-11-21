import { z } from 'zod';

import {
  churchDetailsSchema,
  churchServiceTypes,
  serviceTimesWithMassSchema,
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

/** Followers choose only a church; reminders default to every service on every day. */
export const createChurchSubscriptionSchema = z
  .object({
    churchId: z.uuid(),
    serviceTypes: uniqueServiceTypesSchema.default([...churchServiceTypes]),
    notificationWeekdays: uniqueWeekdaysSchema.default([...weekdayCodes]),
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

export const adminChurchCorrectionSchema = z
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
      serviceTimes: serviceTimesWithMassSchema,
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

export const createAdminChurchSchema = z
  .object({
    church: churchDetailsSchema,
    serviceTimes: serviceTimesWithMassSchema,
  })
  .strict();

export const churchScheduleReviewQuerySchema = z
  .object({
    status: z.enum(['pending', 'completed', 'all']).default('pending'),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();

/** One church in an administrator schedule import file. Matching is by churchId, else name + address + postal code. */
export const importChurchEntrySchema = z
  .object({
    churchId: z.uuid().optional(),
    /** Free-text note so the admin can tell which church an entry is for; never saved. */
    label: z.string().trim().max(300).optional(),
    church: adminChurchCorrectionSchema.optional(),
    serviceTimes: serviceTimesWithMassSchema,
  })
  .strict()
  .refine(
    (entry) =>
      entry.churchId !== undefined ||
      (entry.church?.name !== undefined &&
        entry.church?.addressLine1 !== undefined),
    'Provide churchId, or church.name and church.addressLine1, so the church can be found.',
  );

/** Envelope for the import request; entries are validated one by one so a single bad church never blocks the rest. */
export const importAdminChurchesSchema = z
  .object({
    dryRun: z.boolean().default(true),
    churches: z.array(z.unknown()).min(1).max(200),
  })
  .strict();
