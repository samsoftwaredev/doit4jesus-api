import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const url = new URL(request.url);
    const status = url.searchParams.get('status') ?? 'active';

    if (
      !['active', 'completed', 'expired', 'cancelled', 'all'].includes(status)
    ) {
      throw ApiError.badRequest('Invalid challenge status.');
    }

    let query = supabase
      .schema('competition')
      .from('user_challenge_assignments')
      .select('*')
      .eq('user_id', userId)
      .order('assignment_date', { ascending: false });

    if (status !== 'all')
      query = query.eq(
        'status',
        status as 'active' | 'completed' | 'expired' | 'cancelled',
      );

    const { data: assignments, error } = await query;
    throwDatabaseError(error, 'Unable to load challenges.');

    const rows = assignments ?? [];
    const definitionIds = [
      ...new Set(rows.map((item) => item.challenge_definition_id)),
    ];

    const { data: definitions, error: definitionError } = definitionIds.length
      ? await supabase
          .schema('competition')
          .from('challenge_definitions')
          .select('*')
          .in('id', definitionIds)
      : { data: [], error: null };

    throwDatabaseError(
      definitionError,
      'Unable to load challenge definitions.',
    );
    const definitionMap = new Map(
      (definitions ?? []).map((item) => [item.id, item]),
    );

    return ok(
      rows.map((assignment) => ({
        ...assignment,
        definition:
          definitionMap.get(assignment.challenge_definition_id) ?? null,
        progressPercentage: Number(
          Math.min(
            100,
            (assignment.current_progress / assignment.target_quantity) * 100,
          ).toFixed(2),
        ),
      })),
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
