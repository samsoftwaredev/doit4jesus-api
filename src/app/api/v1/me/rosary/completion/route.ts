import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

function parseOptionalInteger(
  value: string | null,
  parameter: string,
  minimum: number,
  maximum: number,
) {
  if (value === null) return null;

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw ApiError.badRequest(
      `${parameter} must be an integer between ${minimum} and ${maximum}.`,
    );
  }

  return parsed;
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const url = new URL(request.url);
    const selectedYear = parseOptionalInteger(
      url.searchParams.get('selectedYear'),
      'selectedYear',
      1,
      9998,
    );
    const selectedMonth = parseOptionalInteger(
      url.searchParams.get('selectedMonth'),
      'selectedMonth',
      1,
      12,
    );
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_my_rosary_completion', {
        p_year: selectedYear,
        p_month: selectedMonth,
      });

    throwDatabaseError(error, 'Unable to calculate rosary completion.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
