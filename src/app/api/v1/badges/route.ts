import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import { getPublicImageUrl } from '@/lib/supabase/storage';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);

    const [
      definitionsResult,
      earnedResult,
      progressResult,
      requirementsResult,
      requirementProgressResult,
    ] = await Promise.all([
      supabase
        .schema('competition')
        .from('badge_definitions')
        .select('*')
        .eq('is_active', true)
        .order('category'),
      supabase
        .schema('competition')
        .from('user_badges')
        .select('*')
        .eq('user_id', userId)
        .order('earned_at', { ascending: false }),
      supabase
        .schema('competition')
        .from('user_badge_progress')
        .select('*')
        .eq('user_id', userId),
      supabase
        .schema('competition')
        .from('badge_requirement_definitions')
        .select('*')
        .order('display_order'),
      supabase
        .schema('competition')
        .from('user_badge_requirement_progress')
        .select('*')
        .eq('user_id', userId),
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
    for (const earned of earnedResult.data ?? []) {
      const current = earnedByBadge.get(earned.badge_id) ?? [];
      current.push(earned);
      earnedByBadge.set(earned.badge_id, current);
    }

    const progressByBadge = new Map(
      (progressResult.data ?? []).map((progress) => [
        progress.badge_id,
        progress,
      ]),
    );
    const requirementsByBadge = new Map<
      string,
      typeof requirementsResult.data
    >();
    const requirementProgressByRequirement = new Map(
      (requirementProgressResult.data ?? []).map((progress) => [
        progress.badge_requirement_id,
        progress,
      ]),
    );

    for (const requirement of requirementsResult.data ?? []) {
      const current = requirementsByBadge.get(requirement.badge_id) ?? [];
      current.push(requirement);
      requirementsByBadge.set(requirement.badge_id, current);
    }

    return ok(
      (definitionsResult.data ?? []).map((definition) => ({
        definition: {
          ...definition,
          icon_url: getPublicImageUrl(supabase, definition.icon_url),
          locked_icon_url: getPublicImageUrl(
            supabase,
            definition.locked_icon_url,
          ),
        },
        earned: earnedByBadge.get(definition.id) ?? [],
        progress: progressByBadge.get(definition.id) ?? null,
        requirements: (requirementsByBadge.get(definition.id) ?? []).map(
          (requirement) => {
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
      })),
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
