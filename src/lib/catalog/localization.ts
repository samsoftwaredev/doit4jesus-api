import type { SupabaseClient } from '@supabase/supabase-js';
import { z } from 'zod';

import { throwDatabaseError } from '@/lib/api/database';
import type { Database, Json } from '@/lib/supabase/types';

export const catalogLanguageSchema = z.enum(['en', 'es']);
export type CatalogLanguage = z.infer<typeof catalogLanguageSchema>;

type CatalogRow = Record<string, unknown> & { translations?: Json };

export function readCatalogLanguage(url: URL): CatalogLanguage | undefined {
  const language = url.searchParams.get('language');
  return language === null ? undefined : catalogLanguageSchema.parse(language);
}

export function normalizeCatalogLanguage(
  language: string | null | undefined,
): CatalogLanguage {
  const normalized = language?.trim().toLowerCase();
  if (normalized === 'es' || normalized?.startsWith('es-')) return 'es';
  return 'en';
}

export async function resolveCatalogLanguage(
  supabase: SupabaseClient<Database>,
  userId: string,
  explicitLanguage?: CatalogLanguage,
) {
  if (explicitLanguage) return explicitLanguage;

  const { data, error } = await supabase
    .schema('app')
    .from('user_profiles')
    .select('preferred_language')
    .eq('user_id', userId)
    .maybeSingle();
  throwDatabaseError(error, 'Unable to resolve the catalog language.');
  return normalizeCatalogLanguage(data?.preferred_language);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function mergeLocalizedValue(base: unknown, translated: unknown): unknown {
  if (!isObject(base) || !isObject(translated)) return translated;

  return Object.fromEntries(
    Object.entries({ ...base, ...translated }).map(([key, value]) => [
      key,
      key in translated
        ? mergeLocalizedValue(base[key], translated[key])
        : value,
    ]),
  );
}

export function localizeCatalogRow<T extends CatalogRow>(
  row: T,
  language: CatalogLanguage,
): Omit<T, 'translations'> {
  const { translations, ...base } = row;
  if (language === 'en' || !isObject(translations)) return base;

  const localized = translations[language];
  if (!isObject(localized)) return base;
  return mergeLocalizedValue(base, localized) as Omit<T, 'translations'>;
}

export function catalogResponseHeaders(language: CatalogLanguage) {
  return {
    'Cache-Control': 'private, no-store',
    'Content-Language': language,
  };
}

export function publicCatalogResponseHeaders(
  language: CatalogLanguage,
  personalized: boolean,
) {
  return {
    'Cache-Control': personalized
      ? 'private, no-store'
      : 'public, max-age=3600, s-maxage=3600',
    'Content-Language': language,
    Vary: 'Authorization, Cookie',
  };
}
