import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import {
  catalogResponseHeaders,
  localizeCatalogRow,
  readCatalogLanguage,
  resolveCatalogLanguage,
} from '@/lib/catalog/localization';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const language = await resolveCatalogLanguage(
      supabase,
      userId,
      readCatalogLanguage(new URL(request.url)),
    );
    const [demonsResult, saintsResult, affinitiesResult] = await Promise.all([
      supabase
        .schema('competition')
        .from('demon_definitions')
        .select('*')
        .eq('is_active', true)
        .order('category')
        .order('name'),
      supabase
        .schema('competition')
        .from('saint_definitions')
        .select('*')
        .eq('is_active', true),
      supabase
        .schema('competition')
        .from('demon_virtue_affinities')
        .select('*'),
    ]);

    throwDatabaseError(demonsResult.error, 'Unable to load demons.');
    throwDatabaseError(saintsResult.error, 'Unable to load saint mentors.');
    throwDatabaseError(affinitiesResult.error, 'Unable to load demon virtues.');

    const saintsById = new Map(
      (saintsResult.data ?? []).map((saint) => [saint.id, saint]),
    );
    const affinitiesByDemon = new Map<string, typeof affinitiesResult.data>();

    for (const affinity of affinitiesResult.data ?? []) {
      const current = affinitiesByDemon.get(affinity.demon_id) ?? [];
      current.push(affinity);
      affinitiesByDemon.set(affinity.demon_id, current);
    }

    return ok(
      (demonsResult.data ?? [])
        .map((source) => localizeCatalogRow(source, language))
        .sort(
          (left, right) =>
            left.category.localeCompare(right.category) ||
            left.name.localeCompare(right.name, language),
        )
        .map((demon) => ({
          demon,
          saintMentor: demon.saint_mentor_id
            ? saintsById.has(demon.saint_mentor_id)
              ? localizeCatalogRow(
                  saintsById.get(demon.saint_mentor_id)!,
                  language,
                )
              : null
            : null,
          virtueAffinities: affinitiesByDemon.get(demon.id) ?? [],
        })),
      { headers: catalogResponseHeaders(language) },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
