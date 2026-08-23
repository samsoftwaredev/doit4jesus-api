import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, noContent, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { toExaminationQuestion } from '@/lib/examination-of-conscience/question';
import {
  examinationQuestionIdSchema,
  examinationQuestionUpdateSchema,
} from '@/lib/schemas/examination-of-conscience';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ questionId: string }> };

export async function PATCH(request: Request, context: Context) {
  try {
    const questionId = examinationQuestionIdSchema.parse(
      (await context.params).questionId,
    );
    const input = examinationQuestionUpdateSchema.parse(
      await readJson(request),
    );
    const { supabase } = await requireAdmin(request);
    const updates = {
      ...(input.category !== undefined ? { category: input.category } : {}),
      ...(input.title !== undefined ? { title: input.title } : {}),
      ...(input.commandment !== undefined
        ? { commandment: input.commandment }
        : {}),
      ...(input.type !== undefined ? { severity: input.type } : {}),
      ...(input.question !== undefined ? { question: input.question } : {}),
      ...(input.description !== undefined
        ? { description: input.description }
        : {}),
      ...(input.counsels !== undefined ? { counsels: input.counsels } : {}),
      ...(input.prevention !== undefined
        ? { prevention: input.prevention }
        : {}),
      ...(input.saints !== undefined ? { saints: input.saints } : {}),
      ...(input.isActive !== undefined ? { is_active: input.isActive } : {}),
    };
    const { data, error } = await supabase
      .schema('app')
      .from('examination_of_conscience_questions')
      .update(updates)
      .eq('id', questionId)
      .select('*')
      .single();

    throwDatabaseError(error, 'Unable to update the examination question.');
    return ok(toExaminationQuestion(data));
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function DELETE(request: Request, context: Context) {
  try {
    const questionId = examinationQuestionIdSchema.parse(
      (await context.params).questionId,
    );
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('app')
      .from('examination_of_conscience_questions')
      .delete()
      .eq('id', questionId)
      .select('id')
      .maybeSingle();

    throwDatabaseError(error, 'Unable to delete the examination question.');
    if (!data)
      throw ApiError.notFound('The examination question was not found.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
