import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import {
  matchesExaminationFilters,
  resolveExaminationDate,
  selectDailyExaminationQuestion,
} from '@/lib/examination-of-conscience/daily-question';
import { toExaminationQuestion } from '@/lib/examination-of-conscience/question';
import { examinationQuestionQuerySchema } from '@/lib/schemas/examination-of-conscience';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const query = examinationQuestionQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const asOfDate = resolveExaminationDate(query.date);
    const supabase = createAdminClient();
    let dbQuery = supabase
      .schema('app')
      .from('examination_of_conscience_questions')
      .select('*')
      .eq('is_active', true)
      .order('id');

    if (query.category) dbQuery = dbQuery.eq('category', query.category);
    if (query.commandment)
      dbQuery = dbQuery.eq('commandment', query.commandment);
    if (query.type) dbQuery = dbQuery.eq('severity', query.type);

    const { data, error } = await dbQuery;
    throwDatabaseError(error, 'Unable to load examination questions.');
    const questions = (data ?? []).filter((question) =>
      matchesExaminationFilters(question, query),
    );
    if (questions.length === 0) {
      throw ApiError.notFound(
        'No examination-of-conscience question matches these filters.',
      );
    }

    return ok(
      toExaminationQuestion(
        selectDailyExaminationQuestion(questions, asOfDate, query),
      ),
      { headers: { 'Cache-Control': 'public, max-age=3600, s-maxage=3600' } },
      { asOfDate, filters: query },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
