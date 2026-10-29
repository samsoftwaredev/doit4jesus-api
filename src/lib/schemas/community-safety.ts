import { z } from 'zod';

export const safetyTargetTypes = ['user', 'prayer_intention', 'event'] as const;
export const safetyReportReasons = [
  'harassment',
  'threats_hate',
  'sexual_exploitative',
  'privacy',
  'scam_impersonation',
  'infringement',
  'spam_manipulation',
  'other',
] as const;
export const safetyReportStatuses = [
  'open',
  'reviewing',
  'resolved',
  'dismissed',
] as const;

export const userIdSchema = z.uuid();
export const reportIdSchema = z.uuid();

export const createSafetyReportSchema = z
  .object({
    targetType: z.enum(safetyTargetTypes),
    targetId: z.uuid(),
    reason: z.enum(safetyReportReasons),
    details: z.string().trim().min(1).max(2_000).nullable().optional(),
  })
  .strict();

export const adminReportsQuerySchema = z
  .object({
    status: z.enum([...safetyReportStatuses, 'all']).default('open'),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();

export const resolveSafetyReportSchema = z
  .object({
    status: z.enum(['reviewing', 'resolved', 'dismissed']),
    adminNotes: z.string().trim().max(2_000).nullable().optional(),
  })
  .strict();
