import { z } from 'zod';

export const campaignTemplateKeys = ['update', 'announcement'] as const;
export type CampaignTemplateKey = (typeof campaignTemplateKeys)[number];

export const campaignContentSchema = z
  .object({
    previewText: z.string().trim().min(1).max(180),
    heading: z.string().trim().min(1).max(140),
    body: z.string().trim().min(1).max(10_000),
    ctaLabel: z.string().trim().min(1).max(80).optional(),
    ctaUrl: z.url().max(2_000).optional(),
  })
  .strict()
  .superRefine((value, context) => {
    if (Boolean(value.ctaLabel) !== Boolean(value.ctaUrl)) {
      context.addIssue({
        code: 'custom',
        message: 'ctaLabel and ctaUrl must be provided together.',
      });
    }
  });

export type CampaignContent = z.infer<typeof campaignContentSchema>;

export const createEmailCampaignSchema = z
  .object({
    templateKey: z.enum(campaignTemplateKeys),
    subject: z.string().trim().min(1).max(160),
    content: campaignContentSchema,
  })
  .strict();

export const updateEmailCampaignSchema = createEmailCampaignSchema;

export const emailCampaignQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();

export const scheduleEmailCampaignSchema = z
  .object({
    scheduledFor: z.iso.datetime().optional(),
  })
  .strict();

export const createEmailTestRecipientSchema = z
  .object({ email: z.string().trim().email().max(320) })
  .strict();

export const emailTestRecipientQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();

export const contactRequestReplySchema = z
  .object({
    subject: z.string().trim().min(1).max(160),
    message: z.string().trim().min(1).max(10_000),
  })
  .strict();
