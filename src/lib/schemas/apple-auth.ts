import { z } from 'zod';

export const appleCredentialRevocationSchema = z
  .object({ authorizationCode: z.string().trim().min(1).max(4_096) })
  .strict();
