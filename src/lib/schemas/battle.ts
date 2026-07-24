import { z } from 'zod';

export const startEncounterSchema = z
  .object({
    demonCode: z
      .string()
      .trim()
      .min(1)
      .max(100)
      .transform((value) => value.toUpperCase()),
  })
  .strict();

export const encounterIdSchema = z.uuid();
export const defenseAssignmentIdSchema = z.uuid();
