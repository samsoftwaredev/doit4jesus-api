import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import type { AuthenticatedContext } from '@/lib/auth/require-user';
import {
  localizeCatalogRow,
  resolveCatalogLanguage,
} from '@/lib/catalog/localization';
import {
  matchesExaminationFilters,
  selectRandomExaminationQuestion,
} from '@/lib/examination-of-conscience/daily-question';
import { toExaminationQuestion } from '@/lib/examination-of-conscience/question';
import { loadCurrentProfile } from '@/lib/profiles/current-profile';
import type { ScreenDataQuery } from '@/lib/schemas/screen-data';
import { getPublicImageUrl } from '@/lib/supabase/storage';
import {
  applicationToday,
  getMassReadings,
} from '@/liturgy/MassReadingsService';

export type SectionPayload = { data: unknown; meta?: Record<string, unknown> };
type Context = AuthenticatedContext;

function payload(
  data: unknown,
  meta?: Record<string, unknown>,
): SectionPayload {
  return meta ? { data, meta } : { data };
}

async function catalogLanguage(context: Context) {
  return resolveCatalogLanguage(context.supabase, context.userId);
}

export async function loadRosaryStreak(context: Context) {
  const { data, error } = await context.supabase
    .schema('api')
    .rpc('get_my_rosary_streak');
  throwDatabaseError(error, 'Unable to calculate rosary streaks.');
  return payload(data);
}

export async function loadRosaryStats(context: Context) {
  const { data, error } = await context.supabase
    .schema('api')
    .rpc('get_my_rosary_stats');
  throwDatabaseError(error, 'Unable to load rosary statistics.');
  return payload(data);
}

export async function loadRosaryReminder(context: Context) {
  const { data, error } = await context.supabase
    .schema('api')
    .rpc('get_my_daily_rosary_reminder');
  throwDatabaseError(error, 'Unable to load the daily Rosary reminder.');
  return payload(data);
}

export async function loadRosaryCompletion(
  context: Context,
  query: Pick<ScreenDataQuery, 'selectedMonth' | 'selectedYear'>,
) {
  const { data, error } = await context.supabase
    .schema('api')
    .rpc('get_my_rosary_completion', {
      p_year: query.selectedYear ?? null,
      p_month: query.selectedMonth ?? null,
    });
  throwDatabaseError(error, 'Unable to calculate rosary completion.');
  return payload(data);
}

export async function loadProgress(context: Context) {
  const language = await catalogLanguage(context);
  const [
    { data: progress, error: progressError },
    { data: levels, error: levelsError },
  ] = await Promise.all([
    context.supabase
      .schema('competition')
      .from('user_progress')
      .select('*')
      .eq('user_id', context.userId)
      .single(),
    context.supabase
      .schema('competition')
      .from('level_definitions')
      .select('*')
      .eq('is_active', true)
      .order('level_number', { ascending: true }),
  ]);
  throwDatabaseError(progressError, 'Unable to load progression.');
  throwDatabaseError(levelsError, 'Unable to load level definitions.');
  const currentSource =
    levels.find((level) => level.level_number === progress.current_level) ??
    null;
  const nextSource =
    levels.find((level) => level.level_number > progress.current_level) ?? null;
  const current = currentSource
    ? localizeCatalogRow(currentSource, language)
    : null;
  const next = nextSource ? localizeCatalogRow(nextSource, language) : null;
  const currentFloor = current?.minimum_total_xp ?? 0;
  const nextFloor = next?.minimum_total_xp ?? progress.total_xp;
  const denominator = Math.max(1, nextFloor - currentFloor);
  const percentage = next
    ? Math.min(
        100,
        Math.max(0, ((progress.total_xp - currentFloor) / denominator) * 100),
      )
    : 100;
  return payload({
    totalXp: progress.total_xp,
    lifetimePoints: progress.lifetime_points,
    weeklyPoints: progress.weekly_points,
    yearlyPoints: progress.yearly_points,
    lastActivityAt: progress.last_activity_at,
    version: progress.version,
    currentLevel: current,
    nextLevel: next,
    levelProgressPercentage: Number(percentage.toFixed(2)),
    xpIntoCurrentLevel: Math.max(0, progress.total_xp - currentFloor),
    xpRequiredForNextLevel: next ? nextFloor - currentFloor : 0,
    updatedAt: progress.updated_at,
  });
}

export async function loadActivities(
  context: Context,
  activityCode: string,
  limit = 20,
) {
  const { data, error } = await context.supabase
    .schema('competition')
    .from('spiritual_activities')
    .select('*')
    .eq('user_id', context.userId)
    .eq('activity_code', activityCode)
    .order('occurred_at', { ascending: false })
    .limit(limit + 1);
  throwDatabaseError(error, 'Unable to load activities.');
  const hasMore = data.length > limit;
  const items = hasMore ? data.slice(0, limit) : data;
  return payload(items, {
    limit,
    hasMore,
    nextCursor: hasMore ? (items.at(-1)?.occurred_at ?? null) : null,
  });
}

export async function loadLevels(context: Context) {
  const language = await catalogLanguage(context);
  const { data, error } = await context.supabase
    .schema('competition')
    .from('level_definitions')
    .select('*')
    .eq('is_active', true)
    .order('level_number', { ascending: true });
  throwDatabaseError(error, 'Unable to load levels.');
  return payload(
    (data ?? []).map((source) => {
      const level = localizeCatalogRow(source, language);
      return {
        ...level,
        icon_url: getPublicImageUrl(context.supabase, level.icon_url),
        image_url: getPublicImageUrl(context.supabase, level.image_url),
      };
    }),
  );
}

export async function loadExaminationQuestion(context: Context) {
  const language = await catalogLanguage(context);
  const { data, error } = await context.supabase
    .schema('app')
    .from('examination_of_conscience_questions')
    .select('*')
    .eq('is_active', true)
    .order('id');
  throwDatabaseError(error, 'Unable to load examination questions.');
  const questions = (data ?? [])
    .map((question) => ({
      source: question,
      localized: localizeCatalogRow(question, language),
    }))
    .filter(({ localized }) => matchesExaminationFilters(localized, {}));
  if (questions.length === 0) {
    throw ApiError.notFound(
      'No examination-of-conscience question matches these filters.',
    );
  }
  return payload(
    toExaminationQuestion(
      selectRandomExaminationQuestion(questions.map(({ source }) => source)),
      language,
    ),
  );
}

export async function loadPrayerIntentions(context: Context) {
  const limit = 10;
  const offset = 0;
  const { data, error } = await context.supabase
    .schema('prayer')
    .from('prayer_intention_cards')
    .select('*')
    .order('approved_at', { ascending: false })
    .order('id', { ascending: false })
    .range(offset, offset + limit);
  throwDatabaseError(error, 'Unable to load prayer intentions.');
  const rows = data ?? [];
  const hasMore = rows.length > limit;
  return payload(
    rows.slice(0, limit).map((row) => ({
      id: row.id,
      title: row.title,
      description: row.description,
      symbol: row.symbol,
      approvedAt: row.approved_at,
      expiresAt: row.expires_at,
      createdAt: row.created_at,
      prayerCount: row.prayer_count,
      creator: {
        displayName: row.creator_display_name,
        avatarUrl: row.creator_avatar_url,
        countryCode: row.creator_country_code,
      },
    })),
    { limit, offset, hasMore, nextOffset: hasMore ? offset + limit : null },
  );
}

export async function loadCurrentUser(context: Context) {
  return payload(await loadCurrentProfile(context.supabase, context.userId));
}

export async function loadLiturgyToday(
  query: Pick<ScreenDataQuery, 'country' | 'diocese' | 'locale'>,
) {
  const result = await getMassReadings({
    date: applicationToday(),
    country: query.country,
    diocese: query.diocese,
    locale: query.locale,
    includeVerseText: true,
  });
  return payload(result);
}

export async function loadFriends(context: Context) {
  const limit = 20;
  const offset = 0;
  const { data, error } = await context.supabase
    .schema('api')
    .rpc('list_current_user_friends', {
      p_limit: limit + 1,
      p_offset: offset,
      p_include_rosary_streak: true,
    });
  throwDatabaseError(error, 'Unable to load friends.');
  const rows = data ?? [];
  const hasMore = rows.length > limit;
  return payload(
    rows.slice(0, limit).map((friend) => ({
      id: friend.friend_id,
      displayName: friend.display_name,
      username: friend.username,
      avatarUrl: friend.avatar_url,
      title: friend.title,
      countryCode: friend.country_code,
      totalXp: friend.total_xp,
      currentLevel: {
        levelNumber: friend.current_level,
        code: friend.level_code,
        name: friend.level_name,
      },
      rosaryTotal: friend.rosary_total,
      badgeCount: friend.badge_count,
      friendsSince: friend.friends_since,
      rosaryStreak: friend.rosary_streak,
    })),
    { limit, offset, hasMore, nextOffset: hasMore ? offset + limit : null },
  );
}

export async function loadIncomingFriendRequests(context: Context) {
  const limit = 20;
  const offset = 0;
  const { data, error } = await context.supabase
    .schema('api')
    .rpc('list_current_user_friend_requests', {
      p_direction: 'incoming',
      p_status: 'pending',
      p_limit: limit + 1,
      p_offset: offset,
    });
  throwDatabaseError(error, 'Unable to load friend requests.');
  const rows = data ?? [];
  const hasMore = rows.length > limit;
  return payload(
    rows.slice(0, limit).map((friendRequest) => ({
      id: friendRequest.id,
      status: friendRequest.status,
      direction: friendRequest.direction,
      createdAt: friendRequest.created_at,
      respondedAt: friendRequest.responded_at,
      cancelledAt: friendRequest.cancelled_at,
      user: {
        id: friendRequest.user_id,
        displayName: friendRequest.display_name,
        username: friendRequest.username,
        avatarUrl: friendRequest.avatar_url,
        title: friendRequest.title,
        countryCode: friendRequest.country_code,
      },
    })),
    { limit, offset, hasMore, nextOffset: hasMore ? offset + limit : null },
  );
}

export async function loadFriendsLeaderboard(context: Context) {
  const { data, error } = await context.supabase
    .schema('api')
    .rpc('get_current_user_friends_leaderboard', {
      p_period_type: 'weekly',
      p_period_code: null,
      p_limit: 50,
      p_offset: 0,
    });
  throwDatabaseError(error, 'Unable to load the friends leaderboard.');
  return payload(data);
}

export async function loadBadges(context: Context) {
  const language = await catalogLanguage(context);
  const [
    definitionsResult,
    earnedResult,
    progressResult,
    requirementsResult,
    requirementProgressResult,
  ] = await Promise.all([
    context.supabase
      .schema('competition')
      .from('badge_definitions')
      .select('*')
      .eq('is_active', true)
      .order('category'),
    context.supabase
      .schema('competition')
      .from('user_badges')
      .select('*')
      .eq('user_id', context.userId)
      .order('earned_at', { ascending: false }),
    context.supabase
      .schema('competition')
      .from('user_badge_progress')
      .select('*')
      .eq('user_id', context.userId),
    context.supabase
      .schema('competition')
      .from('badge_requirement_definitions')
      .select('*')
      .order('display_order'),
    context.supabase
      .schema('competition')
      .from('user_badge_requirement_progress')
      .select('*')
      .eq('user_id', context.userId),
  ]);
  throwDatabaseError(
    definitionsResult.error,
    'Unable to load badge definitions.',
  );
  throwDatabaseError(earnedResult.error, 'Unable to load earned badges.');
  throwDatabaseError(progressResult.error, 'Unable to load badge progress.');
  throwDatabaseError(
    requirementsResult.error,
    'Unable to load badge requirements.',
  );
  throwDatabaseError(
    requirementProgressResult.error,
    'Unable to load badge requirement progress.',
  );
  const earnedByBadge = new Map<string, typeof earnedResult.data>();
  for (const earned of earnedResult.data ?? [])
    earnedByBadge.set(earned.badge_id, [
      ...(earnedByBadge.get(earned.badge_id) ?? []),
      earned,
    ]);
  const progressByBadge = new Map(
    (progressResult.data ?? []).map((progress) => [
      progress.badge_id,
      progress,
    ]),
  );
  const requirementsByBadge = new Map<string, typeof requirementsResult.data>();
  for (const requirement of requirementsResult.data ?? [])
    requirementsByBadge.set(requirement.badge_id, [
      ...(requirementsByBadge.get(requirement.badge_id) ?? []),
      requirement,
    ]);
  const requirementProgressByRequirement = new Map(
    (requirementProgressResult.data ?? []).map((progress) => [
      progress.badge_requirement_id,
      progress,
    ]),
  );
  return payload(
    (definitionsResult.data ?? []).map((source) => {
      const definition = localizeCatalogRow(source, language);
      return {
        definition: {
          ...definition,
          icon_url: getPublicImageUrl(context.supabase, definition.icon_url),
          locked_icon_url: getPublicImageUrl(
            context.supabase,
            definition.locked_icon_url,
          ),
        },
        earned: earnedByBadge.get(definition.id) ?? [],
        progress: progressByBadge.get(definition.id) ?? null,
        requirements: (requirementsByBadge.get(definition.id) ?? []).map(
          (sourceRequirement) => {
            const requirement = localizeCatalogRow(sourceRequirement, language);
            const requirementProgress = requirementProgressByRequirement.get(
              requirement.id,
            );
            const currentValue = requirementProgress?.current_value ?? 0;
            return {
              definition: requirement,
              currentValue,
              requiredValue: requirement.required_value,
              complete: currentValue >= requirement.required_value,
              completedAt: requirementProgress?.completed_at ?? null,
              updatedAt: requirementProgress?.updated_at ?? null,
            };
          },
        ),
      };
    }),
  );
}

export async function loadLeaderboard(
  context: Context,
  periodType: 'weekly' | 'yearly',
  limit: number,
) {
  const now = new Date().toISOString();
  const { data: periods, error: periodError } = await context.supabase
    .schema('competition')
    .from('leaderboard_periods')
    .select('*')
    .eq('period_type', periodType)
    .eq('status', 'active')
    .lte('starts_at', now)
    .gt('ends_at', now)
    .order('starts_at', { ascending: false })
    .limit(1);
  throwDatabaseError(periodError, 'Unable to load the leaderboard period.');
  const period = periods?.[0];
  if (!period)
    throw ApiError.notFound('No leaderboard period matches the request.');
  const [entriesResponse, currentUserEntryResponse] = await Promise.all([
    context.supabase
      .schema('competition')
      .from('leaderboard_entries')
      .select('*', { count: 'exact' })
      .eq('period_id', period.id)
      .eq('scope_type', 'global')
      .eq('scope_reference', 'global')
      .order('rank', { ascending: true, nullsFirst: false })
      .order('points', { ascending: false })
      .range(0, limit - 1),
    context.supabase
      .schema('competition')
      .from('leaderboard_entries')
      .select('*')
      .eq('period_id', period.id)
      .eq('scope_type', 'global')
      .eq('scope_reference', 'global')
      .eq('user_id', context.userId)
      .maybeSingle(),
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
    ? await context.supabase
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
  const toEntry = (entry: (typeof rows)[number]) => {
    const profile = profileMap.get(entry.user_id);
    return {
      ...entry,
      isCurrentUser: entry.user_id === context.userId,
      profile: {
        user_id: profile?.user_id ?? entry.user_id,
        display_name: profile?.display_name ?? 'Private Player',
        username: profile?.username ?? null,
        avatar_url: profile?.avatar_url ?? null,
        title: profile?.title ?? null,
        countryCode: profile?.country_code ?? null,
        saintAvatarId: profile?.saint_avatar_id ?? null,
      },
    };
  };
  return payload(
    {
      period,
      entries: rows.map(toEntry),
      currentUserEntry: currentUserEntry ? toEntry(currentUserEntry) : null,
    },
    { total: entriesResponse.count ?? 0, limit, offset: 0 },
  );
}
