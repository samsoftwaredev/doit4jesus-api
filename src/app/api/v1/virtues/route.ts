import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const [definitionsResult, valuesResult] = await Promise.all([
      supabase
        .schema('competition')
        .from('virtue_definitions')
        .select('*')
        .eq('is_active', true)
        .order('name'),
      supabase
        .schema('competition')
        .from('user_virtues')
        .select('*')
        .eq('user_id', userId),
    ]);

    throwDatabaseError(
      definitionsResult.error,
      'Unable to load virtue definitions.',
    );
    throwDatabaseError(valuesResult.error, 'Unable to load virtue values.');

    const valuesByCode = new Map(
      (valuesResult.data ?? []).map((value) => [value.virtue_code, value]),
    );

    return ok(
      (definitionsResult.data ?? []).map((definition) => {
        const value = valuesByCode.get(definition.code);

        return {
          definition,
          currentValue: value?.current_value ?? definition.default_value,
          initialized: value !== undefined,
          updatedAt: value?.updated_at ?? null,
        };
      }),
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
