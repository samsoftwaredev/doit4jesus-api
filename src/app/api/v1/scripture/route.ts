import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

function currentReadingDate() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Chicago',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const value = Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  );

  return `${value.year}-${value.month}-${value.day}`;
}

function parseReadingDate(value: string | null) {
  if (value === null) return currentReadingDate();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw ApiError.badRequest('date must use the YYYY-MM-DD format.');
  }

  const parsed = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== value) {
    throw ApiError.badRequest('date must be a valid calendar date.');
  }

  return value;
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const url = new URL(request.url);
    const readingDate = parseReadingDate(url.searchParams.get('date'));
    const { data, error } = await supabase
      .schema('prayer')
      .from('daily_readings')
      .select(
        'reading_date, celebration_name, lectionary_number, scripture_references, scripture_text, text_status',
      )
      .eq('reading_date', readingDate)
      .maybeSingle();

    throwDatabaseError(error, 'Unable to retrieve the daily Scripture.');
    if (!data) {
      throw ApiError.notFound('The daily Scripture is not available for this date.');
    }

    return ok({
      readingDate: data.reading_date,
      celebrationName: data.celebration_name,
      lectionaryNumber: data.lectionary_number,
      scriptureReferences: data.scripture_references,
      scriptureText: data.scripture_text,
      textStatus: data.text_status,
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
