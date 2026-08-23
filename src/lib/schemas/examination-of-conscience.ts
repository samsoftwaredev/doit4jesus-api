import { z } from 'zod';

export const examinationCategories = [
  'single',
  'married',
  'religious',
] as const;
export const examinationTypes = ['mortal', 'grave'] as const;

const textListSchema = z
  .array(z.string().trim().min(1).max(500))
  .min(1)
  .max(12);

const questionFields = {
  category: z.enum(examinationCategories),
  title: z.string().trim().min(1).max(120),
  commandment: z.coerce.number().int().min(1).max(10),
  type: z.enum(examinationTypes),
  question: z.string().trim().min(1).max(1_000),
  description: z.string().trim().min(1).max(4_000),
  counsels: textListSchema,
  prevention: textListSchema,
  saints: textListSchema,
  isActive: z.boolean().optional(),
};

export const examinationQuestionCreateSchema = z
  .object(questionFields)
  .strict();

export const examinationQuestionUpdateSchema = z
  .object({
    ...questionFields,
    category: questionFields.category.optional(),
    title: questionFields.title.optional(),
    commandment: questionFields.commandment.optional(),
    type: questionFields.type.optional(),
    question: questionFields.question.optional(),
    description: questionFields.description.optional(),
    counsels: questionFields.counsels.optional(),
    prevention: questionFields.prevention.optional(),
    saints: questionFields.saints.optional(),
  })
  .strict()
  .refine(
    (value) => Object.keys(value).length > 0,
    'At least one field is required.',
  );

const publicFilters = {
  category: z.enum(examinationCategories).optional(),
  saint: z.string().trim().min(1).max(120).optional(),
  commandment: z.coerce.number().int().min(1).max(10).optional(),
  type: z.enum(examinationTypes).optional(),
  date: z.iso.date().optional(),
};

const randomQuestionQuery = {
  randomQuestion: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
};

export const examinationQuestionQuerySchema = z
  .object({ ...publicFilters, ...randomQuestionQuery })
  .strict();

export const examinationAdminQuerySchema = z
  .object({
    ...publicFilters,
    includeInactive: z
      .enum(['true', 'false'])
      .transform((value) => value === 'true')
      .default(false),
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).default(0),
  })
  .strict();

export const examinationQuestionIdSchema = z.uuid();
