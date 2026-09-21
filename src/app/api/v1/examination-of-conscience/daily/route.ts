import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { getOptionalUser } from '@/lib/auth/optional-user';
import {
  localizeCatalogRow,
  normalizeCatalogLanguage,
  publicCatalogResponseHeaders,
  resolveCatalogLanguage,
} from '@/lib/catalog/localization';
import {
  matchesExaminationFilters,
  resolveExaminationDate,
  selectDailyExaminationQuestion,
} from '@/lib/examination-of-conscience/daily-question';
import { toExaminationQuestion } from '@/lib/examination-of-conscience/question';
import { examinationDailyQuestionQuerySchema } from '@/lib/schemas/examination-of-conscience';
import { createPublicClient } from '@/lib/supabase/public';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const filters = examinationDailyQuestionQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const asOfDate = resolveExaminationDate(filters.date);
    const hasCredentials =
      request.headers.get('authorization') !== null ||
      request.headers.get('cookie') !== null;
    const auth = hasCredentials
      ? await getOptionalUser(request)
      : {
          supabase: createPublicClient(),
          userId: null,
          claims: {},
          authMode: 'anonymous' as const,
        };
    const language = filters.language
      ? filters.language
      : auth.userId
        ? await resolveCatalogLanguage(auth.supabase, auth.userId)
        : normalizeCatalogLanguage(null);
    const personalized = filters.language === undefined && auth.userId !== null;
    const supabase = auth.supabase;
    let query = supabase
      .schema('app')
      .from('examination_of_conscience_questions')
      .select('*')
      .eq('is_active', true)
      .order('id');

    if (filters.category) query = query.eq('category', filters.category);
    if (filters.commandment) {
      query = query.eq('commandment', filters.commandment);
    }
    if (filters.type) query = query.eq('severity', filters.type);

    const { data, error } = await query;
    throwDatabaseError(error, 'Unable to load examination questions.');
    const questions = (data ?? [])
      .map((question) => ({
        source: question,
        localized: localizeCatalogRow(question, language),
      }))
      .filter(({ localized }) => matchesExaminationFilters(localized, filters));

    if (questions.length === 0) {
      throw ApiError.notFound(
        'No examination-of-conscience question matches these filters.',
      );
    }

    const question = selectDailyExaminationQuestion(
      questions.map(({ source }) => source),
      asOfDate,
      filters,
    );

    return ok(
      toExaminationQuestion(question, language),
      { headers: publicCatalogResponseHeaders(language, personalized) },
      { asOfDate, filters },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
