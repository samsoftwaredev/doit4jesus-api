import { z } from 'zod';

export const USERNAME_PATTERN = /^[A-Za-z0-9_]+$/;

export const usernameValueSchema = z
  .string()
  .trim()
  .min(3)
  .max(30)
  .regex(
    USERNAME_PATTERN,
    'Username may contain letters, numbers, and underscores.',
  );

export const usernameValidationQuerySchema = z.object({
  // Ordinary length and character failures are represented in the successful
  // validation response. This upper bound only protects the endpoint itself.
  username: z.string().trim().min(1).max(100),
});
