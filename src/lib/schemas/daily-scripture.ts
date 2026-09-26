import { z } from 'zod';

export const dailyScriptureCompletionSchema = z
  .object({ readingDate: z.iso.date() })
  .strict();
