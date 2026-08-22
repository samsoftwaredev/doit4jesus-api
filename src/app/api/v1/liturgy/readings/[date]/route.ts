import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { getMassReadings } from '@/liturgy/MassReadingsService';

export const dynamic = 'force-dynamic';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ date: string }> },
) {
  try {
    await requireUser(request);
    const { date } = await params;
    const url = new URL(request.url);
    const result = await getMassReadings({
      date,
      country: url.searchParams.get('country') ?? undefined,
      diocese: url.searchParams.get('diocese') ?? undefined,
      locale: url.searchParams.get('locale') ?? undefined,
      includeVerseText: true,
    });
    return ok(result, { headers: { 'Cache-Control': 'private, max-age=300' } });
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
