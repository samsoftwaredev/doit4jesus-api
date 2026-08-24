import { z } from 'zod';

export const contactSubjectValues = [
  'Billing & Payments',
  'Subscription Management',
  'Login & Account Access',
  'App Performance & Bugs',
  'Audio & Playback Issues',
  'Streak & Progress Issues',
  'Content Feedback & Requests',
  'Prayer Intentions',
  'Grammar & Audio Mistakes',
  'Parish & Church Programs',
  'School & Ministry Licensing',
  'Media & Press Inquiries',
  'Other',
] as const;

export type ContactSubject = (typeof contactSubjectValues)[number];

export const contactSubjectOptions: ReadonlyArray<{
  subject: ContactSubject;
  description: string;
}> = [
  {
    subject: 'Billing & Payments',
    description:
      'Premium subscription issues, receipt inquiries, or promotional code problems.',
  },
  {
    subject: 'Subscription Management',
    description:
      'Canceling a free trial, upgrading plans, or managing premium access.',
  },
  {
    subject: 'Login & Account Access',
    description:
      'Forgotten passwords, verification codes, or profile deletion requests.',
  },
  {
    subject: 'App Performance & Bugs',
    description:
      'Reporting issues with app freezing, crashes, or offline download failures.',
  },
  {
    subject: 'Audio & Playback Issues',
    description:
      'Reporting missing audio, slow playback speeds, or Bluetooth connection errors.',
  },
  {
    subject: 'Streak & Progress Issues',
    description:
      'Restoring daily prayer streaks or correcting missing user progress data.',
  },
  {
    subject: 'Content Feedback & Requests',
    description:
      'Suggesting new prayers, Novenas, saints, or specific Bible translations.',
  },
  {
    subject: 'Prayer Intentions',
    description:
      'Issues or questions regarding sharing prayer requests within the app community.',
  },
  {
    subject: 'Grammar & Audio Mistakes',
    description:
      'Reporting typos in scripture text or spoken errors in audio recordings.',
  },
  {
    subject: 'Parish & Church Programs',
    description:
      'Inquiries from pastors or community leaders regarding parish-wide subscriptions.',
  },
  {
    subject: 'School & Ministry Licensing',
    description:
      'Inquiries from schools and youth ministries seeking educational pricing.',
  },
  {
    subject: 'Media & Press Inquiries',
    description:
      'Inquiries from journalists, media outlets, and press representatives.',
  },
  {
    subject: 'Other',
    description:
      'A topic not listed above. Provide a short subject of your own.',
  },
];

export const createContactRequestSchema = z
  .object({
    name: z.string().trim().min(1).max(120),
    email: z.string().trim().email().max(320),
    subject: z.enum(contactSubjectValues),
    otherSubject: z.string().trim().min(2).max(120).optional(),
    message: z.string().trim().min(1).max(5_000),
  })
  .strict()
  .superRefine((value, context) => {
    if (value.subject === 'Other' && !value.otherSubject) {
      context.addIssue({
        code: 'custom',
        path: ['otherSubject'],
        message: 'otherSubject is required when subject is Other.',
      });
    }

    if (value.subject !== 'Other' && value.otherSubject !== undefined) {
      context.addIssue({
        code: 'custom',
        path: ['otherSubject'],
        message: 'otherSubject may only be provided when subject is Other.',
      });
    }
  });

export const contactRequestAdminQuerySchema = z
  .object({
    status: z.enum(['todo', 'inprogress', 'done', 'all']).default('all'),
    // A calendar date is interpreted as the full UTC day, rather than an
    // impractical exact match against a timestamp with milliseconds.
    created_at: z.iso.date().optional(),
    email: z.string().trim().email().max(320).optional(),
    name: z.string().trim().min(1).max(120).optional(),
    subject: z.enum(contactSubjectValues).optional(),
    limit: z.coerce.number().int().min(1).max(100).default(20),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();
