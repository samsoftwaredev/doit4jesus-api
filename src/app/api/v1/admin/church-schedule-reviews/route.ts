import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { weekdayName } from '@/lib/churches/live-status';
import { churchScheduleReviewQuerySchema } from '@/lib/schemas/church-subscription';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const query = churchScheduleReviewQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    let taskQuery = supabase
      .schema('app')
      .from('church_schedule_review_tasks')
      .select('*')
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .range(query.offset, query.offset + query.limit);
    if (query.status !== 'all')
      taskQuery = taskQuery.eq('status', query.status);
    const { data: taskRows, error: tasksError } = await taskQuery;
    throwDatabaseError(tasksError, 'Unable to load church schedule reviews.');
    const rows = taskRows ?? [];
    const hasMore = rows.length > query.limit;
    const tasks = rows.slice(0, query.limit);
    const churchIds = tasks.map((task) => task.church_id);

    const [churchesResult, serviceTimesResult, subscriptionsResult] =
      churchIds.length
        ? await Promise.all([
            supabase
              .schema('app')
              .from('churches')
              .select('*')
              .in('id', churchIds),
            supabase
              .schema('app')
              .from('church_service_times')
              .select('*')
              .in('church_id', churchIds)
              .order('weekday')
              .order('starts_at'),
            supabase
              .schema('app')
              .from('church_subscriptions')
              .select('church_id')
              .in('church_id', churchIds),
          ])
        : [
            { data: [], error: null },
            { data: [], error: null },
            { data: [], error: null },
          ];
    throwDatabaseError(churchesResult.error, 'Unable to load review churches.');
    throwDatabaseError(
      serviceTimesResult.error,
      'Unable to load review schedules.',
    );
    throwDatabaseError(
      subscriptionsResult.error,
      'Unable to count church subscribers.',
    );
    const churchesById = new Map(
      (churchesResult.data ?? []).map((church) => [church.id, church]),
    );

    return ok(
      tasks.flatMap((task) => {
        const church = churchesById.get(task.church_id);
        if (!church) return [];
        return [
          {
            id: task.id,
            status: task.status,
            outcome: task.outcome,
            church: {
              id: church.id,
              name: church.name,
              address: {
                line1: church.address_line_1,
                line2: church.address_line_2,
                city: church.city,
                regionName: church.region_name,
                postalCode: church.postal_code,
                countryCode: church.country_code,
              },
              timezone: church.timezone,
              latitude: church.latitude,
              longitude: church.longitude,
              directoryVerificationStatus: church.directory_verification_status,
              source: church.source,
              sourceId: church.source_id,
              sourceRelease: church.source_release,
              sourceConfidence: church.source_confidence,
              scheduleVerifiedAt: church.schedule_verified_at,
            },
            subscriberCount: (subscriptionsResult.data ?? []).filter(
              (subscription) => subscription.church_id === church.id,
            ).length,
            schedule: (serviceTimesResult.data ?? [])
              .filter((serviceTime) => serviceTime.church_id === church.id)
              .map((serviceTime) => ({
                id: serviceTime.id,
                serviceType: serviceTime.service_type,
                weekday: weekdayName(serviceTime.weekday),
                startTime: serviceTime.starts_at.slice(0, 5),
                endTime: serviceTime.ends_at?.slice(0, 5) ?? null,
              })),
            requestedBy: task.requested_by,
            reviewReason: task.request_reason,
            createdAt: task.created_at,
            completedBy: task.completed_by,
            completedAt: task.completed_at,
            completionReason: task.completion_reason,
          },
        ];
      }),
      { headers: { 'Cache-Control': 'no-store' } },
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
