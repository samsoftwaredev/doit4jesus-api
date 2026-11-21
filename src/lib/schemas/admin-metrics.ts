import { z } from 'zod';

export const adminMetricKeys = [
  'total_users',
  'dau',
  'wau',
  'mau',
  'signups_7d',
  'signups_30d',
  'retention_d1',
  'retention_d7',
  'retention_d30',
  'signup_to_active',
  'profile_setup',
  'first_practice_7d',
  'churn',
  'rosary_completion',
] as const;

export const adminMetricUsersQuerySchema = z.object({
  metric: z.enum(adminMetricKeys),
  filter: z.enum(['all', 'yes', 'no']).default('all'),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
});

export type AdminMetricKey = (typeof adminMetricKeys)[number];
