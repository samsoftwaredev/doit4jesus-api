import type { Database } from '@/lib/supabase/types';

export type ExaminationQuestion =
  Database['app']['Tables']['examination_of_conscience_questions']['Row'];

/**
 * Keeps the public API terminology (`type`) independent from the persistence
 * column (`severity`), which avoids using the reserved-sounding SQL name type.
 */
export function toExaminationQuestion(question: ExaminationQuestion) {
  return {
    id: question.id,
    category: question.category,
    title: question.title,
    commandment: question.commandment,
    type: question.severity,
    question: question.question,
    description: question.description,
    counsels: question.counsels,
    prevention: question.prevention,
    saints: question.saints,
    isActive: question.is_active,
    createdAt: question.created_at,
    updatedAt: question.updated_at,
  };
}
