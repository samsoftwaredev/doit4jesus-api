import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { toExaminationQuestion } from '@/lib/examination-of-conscience/question';
import {
  examinationAdminQuerySchema,
  examinationQuestionCreateSchema,
} from '@/lib/schemas/examination-of-conscience';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const query = examinationAdminQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let dbQuery = supabase
      .schema('app')
      .from('examination_of_conscience_questions')
      .select('*')
      .order('created_at', { ascending: false });

    if (!query.includeInactive) dbQuery = dbQuery.eq('is_active', true);
    if (query.category) dbQuery = dbQuery.eq('category', query.category);
    if (query.commandment)
      dbQuery = dbQuery.eq('commandment', query.commandment);
    if (query.type) dbQuery = dbQuery.eq('severity', query.type);
    // Saint matching is case-insensitive, so it is intentionally done in
    // memory. Apply the database range only when no in-memory filter exists.
    if (!query.saint)
      dbQuery = dbQuery.range(query.offset, query.offset + query.limit);

    const { data, error } = await dbQuery;
    throwDatabaseError(error, 'Unable to load examination questions.');
    const rows = (data ?? []).filter(
      (question) =>
        !query.saint ||
        question.saints.some(
          (saint) =>
            saint.localeCompare(query.saint!, undefined, {
              sensitivity: 'accent',
            }) === 0,
        ),
    );

    const pagedRows = query.saint
      ? rows.slice(query.offset, query.offset + query.limit + 1)
      : rows;
    const hasMore = pagedRows.length > query.limit;
    return ok(
      pagedRows.slice(0, query.limit).map(toExaminationQuestion),
      {},
      {
        limit: query.limit,
        offset: query.offset,
        hasMore,
        nextOffset: hasMore ? query.offset + query.limit : null,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function POST(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const input = examinationQuestionCreateSchema.parse(
      await readJson(request),
    );
    const { data, error } = await supabase
      .schema('app')
      .from('examination_of_conscience_questions')
      .insert({
        category: input.category,
        title: input.title,
        commandment: input.commandment,
        severity: input.type,
        question: input.question,
        description: input.description,
        counsels: input.counsels,
        prevention: input.prevention,
        saints: input.saints,
        is_active: input.isActive ?? true,
      })
      .select('*')
      .single();

    throwDatabaseError(error, 'Unable to create the examination question.');
    return created(toExaminationQuestion(data));
  } catch (error) {
    return errorResponse(error, request);
  }
}
