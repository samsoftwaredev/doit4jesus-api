import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { requireIdempotencyKey } from '@/lib/api/idempotency';
import { created, errorResponse, ok } from '@/lib/api/response';
import { parsePositiveInt, readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import {
  catalogResponseHeaders,
  localizeCatalogRow,
  readCatalogLanguage,
  resolveCatalogLanguage,
} from '@/lib/catalog/localization';
import { startEncounterSchema } from '@/lib/schemas/battle';

export const dynamic = 'force-dynamic';

const encounterStatuses = new Set([
  'active',
  'defeated',
  'abandoned',
  'expired',
]);
type EncounterStatus = 'active' | 'defeated' | 'abandoned' | 'expired';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const url = new URL(request.url);
    const language = await resolveCatalogLanguage(
      supabase,
      userId,
      readCatalogLanguage(url),
    );
    const limit = parsePositiveInt(url.searchParams.get('limit'), 20, 100);
    const before = url.searchParams.get('before');
    const status = url.searchParams.get('status');

    if (status && status !== 'all' && !encounterStatuses.has(status)) {
      throw ApiError.badRequest(
        'status must be active, defeated, abandoned, expired, or all.',
      );
    }

    let query = supabase
      .schema('competition')
      .from('user_demon_encounters')
      .select('*')
      .eq('user_id', userId)
      .order('started_at', { ascending: false })
      .limit(limit + 1);

    if (before) query = query.lt('started_at', before);
    if (status && status !== 'all')
      query = query.eq('status', status as EncounterStatus);

    const { data: encounters, error: encountersError } = await query;
    throwDatabaseError(encountersError, 'Unable to load encounters.');

    const hasMore = (encounters ?? []).length > limit;
    const items = hasMore
      ? (encounters ?? []).slice(0, limit)
      : (encounters ?? []);
    const demonIds = [...new Set(items.map((encounter) => encounter.demon_id))];
    const { data: demons, error: demonsError } = demonIds.length
      ? await supabase
          .schema('competition')
          .from('demon_definitions')
          .select('*')
          .in('id', demonIds)
      : { data: [], error: null };

    throwDatabaseError(demonsError, 'Unable to load encounter demons.');
    const demonsById = new Map(
      (demons ?? []).map((demon) => [demon.id, demon]),
    );

    return ok(
      items.map((encounter) => ({
        encounter,
        demon: demonsById.has(encounter.demon_id)
          ? localizeCatalogRow(demonsById.get(encounter.demon_id)!, language)
          : null,
      })),
      { headers: catalogResponseHeaders(language) },
      {
        limit,
        hasMore,
        nextCursor: hasMore ? (items.at(-1)?.started_at ?? null) : null,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const idempotencyKey = requireIdempotencyKey(request);
    const input = startEncounterSchema.parse(await readJson(request));
    const { data, error } = await supabase
      .schema('api')
      .rpc('start_demon_encounter', {
        p_demon_code: input.demonCode,
        p_idempotency_key: idempotencyKey,
      });

    throwDatabaseError(error, 'Unable to start the demon encounter.');
    const replayed = Boolean(
      (data as Record<string, unknown> | null)?.replayed,
    );
    return replayed ? ok(data) : created(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
