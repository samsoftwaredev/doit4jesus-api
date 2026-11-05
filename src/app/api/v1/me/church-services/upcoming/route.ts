import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { upcomingChurchServicesQuerySchema } from '@/lib/schemas/church-subscription';

export const dynamic = 'force-dynamic';

function localTime(value: string | null) {
  return value ? value.slice(0, 5) : null;
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const query = upcomingChurchServicesQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { data, error } = await supabase
      .schema('api')
      .rpc('get_my_upcoming_church_services', {
        p_from: query.from ?? new Date().toISOString(),
        p_days: query.days,
        p_church_id: query.churchId ?? null,
        p_service_type: query.serviceType ?? null,
        p_limit: query.limit + 1,
        p_offset: query.offset,
      });
    throwDatabaseError(error, 'Unable to load upcoming church services.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    const items = rows.slice(0, query.limit);
    return ok(
      items.map((item) => ({
        occurrenceId: item.occurrence_id,
        serviceTimeId: item.service_time_id,
        church: { id: item.church_id, name: item.church_name },
        serviceType: item.service_type,
        startsAt: item.starts_at,
        endsAt: item.ends_at,
        localDate: item.local_date,
        localStartTime: localTime(item.local_start_time),
        localEndTime: localTime(item.local_end_time),
        timezone: item.timezone,
      })),
      { headers: { 'Cache-Control': 'no-store' } },
      {
        days: query.days,
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
