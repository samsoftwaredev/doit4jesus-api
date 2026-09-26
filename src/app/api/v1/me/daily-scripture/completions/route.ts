import { throwDatabaseError } from '@/lib/api/database';
import { requireIdempotencyKey } from '@/lib/api/idempotency';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { dailyScriptureCompletionSchema } from '@/lib/schemas/daily-scripture';
import { getMassReadings } from '@/liturgy/MassReadingsService';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const idempotencyKey = requireIdempotencyKey(request);
    const input = dailyScriptureCompletionSchema.parse(await readJson(request));

    await getMassReadings({
      date: input.readingDate,
      country: 'US',
      includeVerseText: false,
    });
    const { data, error } = await supabase
      .schema('api')
      .rpc('complete_daily_scripture', {
        p_reading_date: input.readingDate,
        p_idempotency_key: idempotencyKey,
      });
    throwDatabaseError(error, 'Unable to complete Daily Scripture.');

    return (data as Record<string, unknown> | null)?.replayed
      ? ok(data)
      : created(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
