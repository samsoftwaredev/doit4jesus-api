import type { ExaminationQuestion } from '@/lib/examination-of-conscience/question';

export type ExaminationQuestionFilters = {
  category?: string;
  saint?: string;
  commandment?: number;
  type?: string;
};

function todayInTimezone(timezone: string) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value;

  return `${value('year')}-${value('month')}-${value('day')}`;
}

export function resolveExaminationDate(date?: string) {
  return (
    date ??
    todayInTimezone(process.env.EXAMINATION_TIMEZONE ?? 'America/Chicago')
  );
}

export function matchesExaminationFilters(
  question: ExaminationQuestion,
  filters: ExaminationQuestionFilters,
) {
  if (filters.category && question.category !== filters.category) return false;
  if (filters.commandment && question.commandment !== filters.commandment)
    return false;
  if (filters.type && question.severity !== filters.type) return false;

  return (
    !filters.saint ||
    question.saints.some(
      (saint) =>
        saint.localeCompare(filters.saint!, undefined, {
          sensitivity: 'accent',
        }) === 0,
    )
  );
}

function hash(value: string) {
  let result = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    result = Math.imul(result ^ value.charCodeAt(index), 16777619);
  }
  return result >>> 0;
}

export function selectDailyExaminationQuestion(
  questions: ExaminationQuestion[],
  asOfDate: string,
  filters: ExaminationQuestionFilters,
) {
  const key = [
    asOfDate,
    filters.category ?? '',
    filters.saint?.toLocaleLowerCase() ?? '',
    filters.commandment ?? '',
    filters.type ?? '',
  ].join('|');
  // Question text is unique in the database and remains stable across seed
  // resets, unlike generated row UUIDs.
  const orderedQuestions = [...questions].sort((left, right) =>
    left.question.localeCompare(right.question),
  );

  return orderedQuestions[hash(key) % orderedQuestions.length];
}
