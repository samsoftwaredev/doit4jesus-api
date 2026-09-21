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
  selectRandomExaminationQuestion,
} from '@/lib/examination-of-conscience/daily-question';
import { toExaminationQuestion } from '@/lib/examination-of-conscience/question';
import { examinationQuestionQuerySchema } from '@/lib/schemas/examination-of-conscience';
import { createPublicClient } from '@/lib/supabase/public';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const query = examinationQuestionQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
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
    const language = query.language
      ? query.language
      : auth.userId
        ? await resolveCatalogLanguage(auth.supabase, auth.userId)
        : normalizeCatalogLanguage(null);
    const personalized = query.language === undefined && auth.userId !== null;
    const supabase = auth.supabase;
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
    const questions = (data ?? [])
      .map((question) => ({
        source: question,
        localized: localizeCatalogRow(question, language),
      }))
      .filter(({ localized }) => matchesExaminationFilters(localized, query));

    if (query.randomQuestion && questions.length === 0) {
      throw ApiError.notFound(
        'No examination-of-conscience question matches these filters.',
      );
    }

    if (query.randomQuestion) {
      return ok(
        toExaminationQuestion(
          selectRandomExaminationQuestion(
            questions.map(({ source }) => source),
          ),
          language,
        ),
        {
          headers: publicCatalogResponseHeaders(language, true),
        },
      );
    }

    return ok(
      questions.map(({ source }) => toExaminationQuestion(source, language)),
      {
        headers: publicCatalogResponseHeaders(language, personalized),
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
