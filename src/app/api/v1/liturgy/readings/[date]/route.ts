import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { loadDailyScriptureCompletion } from '@/lib/liturgy/completion';
import { getMassReadings } from '@/liturgy/MassReadingsService';

export const dynamic = 'force-dynamic';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ date: string }> },
) {
  try {
    const { supabase } = await requireUser(request);
    const { date } = await params;
    const url = new URL(request.url);
    const result = await getMassReadings({
      date,
      country: url.searchParams.get('country') ?? undefined,
      diocese: url.searchParams.get('diocese') ?? undefined,
      locale: url.searchParams.get('locale') ?? undefined,
      includeVerseText: true,
    });
    const completion = await loadDailyScriptureCompletion(
      supabase,
      result.date,
    );
    return ok(
      { ...result, completion },
      {
        headers: {
          'Cache-Control': 'private, max-age=300',
          'Content-Language':
            result.metadata?.scriptureTextSource === 'BIBLIA_DE_JERUSALEN'
              ? 'es'
              : 'en',
        },
      },
    );
  } catch (error) {
    return errorResponse(
      error instanceof Error
        ? error
        : new ApiError(
            500,
            'LITURGY_RESOLUTION_ERROR',
            'Unable to resolve Mass readings.',
          ),
      request,
    );
  }
}
