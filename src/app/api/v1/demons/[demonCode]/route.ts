import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

type Context = { params: Promise<{ demonCode: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const { demonCode } = await context.params;
    const { supabase } = await requireUser(request);
    const normalizedCode = demonCode.trim().toUpperCase();
    const { data: demon, error: demonError } = await supabase
      .schema('competition')
      .from('demon_definitions')
      .select('*')
      .eq('code', normalizedCode)
      .eq('is_active', true)
      .maybeSingle();

    throwDatabaseError(demonError, 'Unable to load the demon.');
    if (!demon) throw ApiError.notFound('The demon was not found.');

    const [
      saintResult,
      attacksResult,
      defensesResult,
      affinitiesResult,
      rewardResult,
    ] = await Promise.all([
      demon.saint_mentor_id
        ? supabase
            .schema('competition')
            .from('saint_definitions')
            .select('*')
            .eq('id', demon.saint_mentor_id)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      supabase
        .schema('competition')
        .from('demon_attacks')
        .select('*')
        .eq('demon_id', demon.id)
        .order('code'),
      supabase
        .schema('competition')
        .from('demon_defenses')
        .select('*')
        .eq('demon_id', demon.id)
        .order('code'),
      supabase
        .schema('competition')
        .from('demon_virtue_affinities')
        .select('*')
        .eq('demon_id', demon.id),
      supabase
        .schema('competition')
        .from('demon_defeat_rewards')
        .select('*')
        .eq('demon_id', demon.id)
        .maybeSingle(),
    ]);

    throwDatabaseError(saintResult.error, 'Unable to load the saint mentor.');
    throwDatabaseError(attacksResult.error, 'Unable to load demon attacks.');
    throwDatabaseError(defensesResult.error, 'Unable to load demon defenses.');
    throwDatabaseError(affinitiesResult.error, 'Unable to load demon virtues.');
    throwDatabaseError(rewardResult.error, 'Unable to load the defeat reward.');

    return ok({
      demon,
      saintMentor: saintResult.data,
      attacks: attacksResult.data ?? [],
      defenses: defensesResult.data ?? [],
      virtueAffinities: affinitiesResult.data ?? [],
      defeatReward: rewardResult.data,
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
