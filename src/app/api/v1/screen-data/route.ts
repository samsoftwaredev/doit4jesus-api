import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { screenDataQuerySchema } from '@/lib/schemas/screen-data';
import {
  type SectionPayload,
  loadActivities,
  loadBadges,
  loadCurrentUser,
  loadExaminationQuestion,
  loadFriends,
  loadFriendsLeaderboard,
  loadIncomingFriendRequests,
  loadLeaderboard,
  loadLevels,
  loadLiturgyToday,
  loadPrayerIntentions,
  loadProgress,
  loadRosaryCompletion,
  loadRosaryReminder,
  loadRosaryStats,
  loadRosaryStreak,
} from '@/lib/screen-data/loaders';

export const dynamic = 'force-dynamic';

type SectionError = { code: string; message: string };
type Loader = () => Promise<SectionPayload>;

function safeSectionError(error: unknown): SectionError {
  if (error instanceof ApiError) {
    return { code: error.code, message: error.message };
  }

  return {
    code: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred.',
  };
}

async function loadSections(loaders: Record<string, Loader>) {
  const entries = Object.entries(loaders);
  const results = await Promise.allSettled(
    entries.map(([, loader]) => loader()),
  );
  const sections: Record<string, SectionPayload | null> = {};
  const errors: Record<string, SectionError> = {};

  results.forEach((result, index) => {
    const name = entries[index][0];
    if (result.status === 'fulfilled') {
      sections[name] = result.value;
      return;
    }

    sections[name] = null;
    errors[name] = safeSectionError(result.reason);
  });

  return { sections, errors };
}

export async function GET(request: Request) {
  try {
    const context = await requireUser(request);
    const query = screenDataQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );

    const loaders: Record<string, Loader> =
      query.screen === 'home'
        ? {
            rosaryStreak: () => loadRosaryStreak(context),
            rosaryStats: () => loadRosaryStats(context),
            progress: () => loadProgress(context),
            rosaryReminder: () => loadRosaryReminder(context),
            liturgyToday: () => loadLiturgyToday(query),
            scriptureActivities: () => loadActivities(context, 'SCRIPTURE'),
            levels: () => loadLevels(context),
            rosaryActivities: () => loadActivities(context, 'ROSARY'),
            examinationQuestion: () => loadExaminationQuestion(context),
            badges: () => loadBadges(context),
          }
        : query.screen === 'prayer'
          ? {
              prayerIntentions: () => loadPrayerIntentions(context),
              me: () => loadCurrentUser(context),
              rosaryCompletion: () => loadRosaryCompletion(context, query),
              rosaryStreak: () => loadRosaryStreak(context),
              weeklyGlobalLeaderboard: () =>
                loadLeaderboard(context, 'weekly', 3),
              yearlyGlobalLeaderboard: () =>
                loadLeaderboard(context, 'yearly', 10),
            }
          : {
              friends: () => loadFriends(context),
              incomingFriendRequests: () => loadIncomingFriendRequests(context),
              friendsWeeklyLeaderboard: () => loadFriendsLeaderboard(context),
            };
    const { sections, errors } = await loadSections(loaders);

    return ok(
      { screen: query.screen, sections },
      { headers: { 'Cache-Control': 'no-store' } },
      { errors },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
