import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';
import {
  catalogResponseHeaders,
  localizeCatalogRow,
  readCatalogLanguage,
  resolveCatalogLanguage,
} from '@/lib/catalog/localization';
import { getPublicImageUrl } from '@/lib/supabase/storage';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase, userId } = await requireUser(request);
    const language = await resolveCatalogLanguage(
      supabase,
      userId,
      readCatalogLanguage(new URL(request.url)),
    );
    const { data, error } = await supabase
      .schema('competition')
      .from('level_definitions')
      .select('*')
      .eq('is_active', true)
      .order('level_number', { ascending: true });

    throwDatabaseError(error, 'Unable to load levels.');
    return ok(
      (data ?? []).map((source) => {
        const level = localizeCatalogRow(source, language);
        return {
          ...level,
          icon_url: getPublicImageUrl(supabase, level.icon_url),
          image_url: getPublicImageUrl(supabase, level.image_url),
        };
      }),
      { headers: catalogResponseHeaders(language) },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
