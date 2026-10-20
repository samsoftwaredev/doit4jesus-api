import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { toLeaderboardResponseEntry } from '@/lib/leaderboards/response';
import { leaderboardQuerySchema } from '@/lib/schemas/leaderboard';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const url = new URL(request.url);
    const query = leaderboardQuerySchema.parse(
      Object.fromEntries(url.searchParams.entries()),
    );

    const now = new Date().toISOString();
    let periodQuery = supabase
      .schema('competition')
      .from('leaderboard_periods')
      .select('*')
      .eq('period_type', query.periodType);

    periodQuery = query.periodCode
      ? periodQuery.eq('code', query.periodCode)
      : periodQuery
          .eq('status', 'active')
          .lte('starts_at', now)
          .gt('ends_at', now)
          .order('starts_at', { ascending: false });

    const { data: periods, error: periodError } = await periodQuery.limit(1);
    throwDatabaseError(periodError, 'Unable to load the leaderboard period.');
    const period = periods?.[0];
    if (!period)
      throw ApiError.notFound('No leaderboard period matches the request.');

    let entriesQuery = supabase
      .schema('competition')
      .from('leaderboard_entries')
      .select('*', { count: 'exact' })
      .eq('period_id', period.id)
      .eq('scope_type', query.scopeType)
      .eq('scope_reference', query.scopeReference);
    let currentUserEntryQuery = supabase
      .schema('competition')
      .from('leaderboard_entries')
      .select('*')
      .eq('period_id', period.id)
      .eq('scope_type', query.scopeType)
      .eq('scope_reference', query.scopeReference)
      .eq('user_id', userId);

    if (query.scopeType === 'global') {
      entriesQuery = entriesQuery
        .gt('rosaries_count', 0)
        .order('rank', { ascending: true, nullsFirst: false })
        .order('rosaries_count', { ascending: false })
        .order('user_id', { ascending: true });
      currentUserEntryQuery = currentUserEntryQuery.gt('rosaries_count', 0);
    } else {
      entriesQuery = entriesQuery
        .order('rank', { ascending: true, nullsFirst: false })
        .order('points', { ascending: false });
    }

    const [entriesResponse, currentUserEntryResponse] = await Promise.all([
      entriesQuery.range(query.offset, query.offset + query.limit - 1),
      currentUserEntryQuery.maybeSingle(),
    ]);

    throwDatabaseError(
      entriesResponse.error,
      'Unable to load leaderboard entries.',
    );
    throwDatabaseError(
      currentUserEntryResponse.error,
      'Unable to load the current user leaderboard entry.',
    );

    const rows = entriesResponse.data ?? [];
    const currentUserEntry = currentUserEntryResponse.data;
    const userIds = [
      ...new Set([
        ...rows.map((entry) => entry.user_id),
        ...(currentUserEntry ? [currentUserEntry.user_id] : []),
      ]),
    ];

    const { data: profiles, error: profileError } = userIds.length
      ? await supabase
          .schema('app')
          .from('leaderboard_profiles')
          .select(
            'user_id,display_name,username,avatar_url,title,country_code,saint_avatar_id',
          )
          .in('user_id', userIds)
      : { data: [], error: null };

    throwDatabaseError(profileError, 'Unable to load leaderboard profiles.');
    const profileMap = new Map(
      (profiles ?? []).map((profile) => [profile.user_id, profile]),
    );
    const toResponseEntry = (entry: (typeof rows)[number]) => {
      const profile = profileMap.get(entry.user_id);

      return toLeaderboardResponseEntry(
        entry,
        profile,
        userId,
        query.scopeType === 'global',
      );
    };

    return ok(
      {
        period,
        entries: rows.map(toResponseEntry),
        currentUserEntry: currentUserEntry
          ? toResponseEntry(currentUserEntry)
          : null,
      },
      {},
      {
        total: entriesResponse.count ?? 0,
        limit: query.limit,
        offset: query.offset,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
