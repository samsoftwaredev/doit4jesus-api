import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { parsePositiveInt } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { encounterIdSchema } from '@/lib/schemas/battle';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ encounterId: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const { encounterId: rawEncounterId } = await context.params;
    const encounterId = encounterIdSchema.parse(rawEncounterId);
    const { supabase, userId } = await requireUser(request);
    const url = new URL(request.url);
    const timelineLimit = parsePositiveInt(
      url.searchParams.get('timelineLimit'),
      20,
      100,
    );
    const timelineBefore = url.searchParams.get('timelineBefore');

    const { data: encounter, error: encounterError } = await supabase
      .schema('competition')
      .from('user_demon_encounters')
      .select('*')
      .eq('id', encounterId)
      .eq('user_id', userId)
      .maybeSingle();

    throwDatabaseError(encounterError, 'Unable to load the encounter.');
    if (!encounter) throw ApiError.notFound('The encounter was not found.');

    let battleEventsQuery = supabase
      .schema('competition')
      .from('demon_battle_events')
      .select('*')
      .eq('encounter_id', encounter.id)
      .order('occurred_at', { ascending: false })
      .limit(timelineLimit + 1);

    if (timelineBefore)
      battleEventsQuery = battleEventsQuery.lt('occurred_at', timelineBefore);

    const [demonResult, assignmentsResult, battleEventsResult] =
      await Promise.all([
        supabase
          .schema('competition')
          .from('demon_definitions')
          .select('*')
          .eq('id', encounter.demon_id)
          .maybeSingle(),
        supabase
          .schema('competition')
          .from('user_demon_defense_assignments')
          .select('*')
          .eq('encounter_id', encounter.id)
          .order('assignment_sequence'),
        battleEventsQuery,
      ]);

    throwDatabaseError(
      demonResult.error,
      'Unable to load the encounter demon.',
    );
    throwDatabaseError(
      assignmentsResult.error,
      'Unable to load defense assignments.',
    );
    throwDatabaseError(
      battleEventsResult.error,
      'Unable to load the battle timeline.',
    );

    const assignments = assignmentsResult.data ?? [];
    const defenseIds = [
      ...new Set(assignments.map((assignment) => assignment.defense_id)),
    ];
    const eventRows = battleEventsResult.data ?? [];
    const hasMore = eventRows.length > timelineLimit;
    const timelineItems = hasMore
      ? eventRows.slice(0, timelineLimit)
      : eventRows;
    const virtueEventIds = [
      ...new Set(timelineItems.map((event) => event.virtue_event_id)),
    ];

    const [defensesResult, virtueEventsResult] = await Promise.all([
      defenseIds.length
        ? supabase
            .schema('competition')
            .from('demon_defenses')
            .select('*')
            .in('id', defenseIds)
        : Promise.resolve({ data: [], error: null }),
      virtueEventIds.length
        ? supabase
            .schema('competition')
            .from('virtue_events')
            .select('*')
            .in('id', virtueEventIds)
        : Promise.resolve({ data: [], error: null }),
    ]);

    throwDatabaseError(
      defensesResult.error,
      'Unable to load defense definitions.',
    );
    throwDatabaseError(
      virtueEventsResult.error,
      'Unable to load virtue events.',
    );

    const defensesById = new Map(
      (defensesResult.data ?? []).map((defense) => [defense.id, defense]),
    );
    const virtueEventsById = new Map(
      (virtueEventsResult.data ?? []).map((event) => [event.id, event]),
    );

    return ok(
      {
        encounter,
        demon: demonResult.data,
        assignments: assignments.map((assignment) => ({
          assignment,
          defense: defensesById.get(assignment.defense_id) ?? null,
        })),
        timeline: timelineItems.map((event) => ({
          event,
          virtueEvent: virtueEventsById.get(event.virtue_event_id) ?? null,
        })),
      },
      {},
      {
        timelineLimit,
        hasMore,
        nextTimelineCursor: hasMore
          ? (timelineItems.at(-1)?.occurred_at ?? null)
          : null,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
