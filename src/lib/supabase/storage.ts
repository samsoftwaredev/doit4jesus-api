import type { SupabaseClient } from '@supabase/supabase-js';

import type { Database } from '@/lib/supabase/types';

const DEFAULT_PUBLIC_IMAGE_BUCKET = 'images';

function isAbsoluteUrl(value: string) {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

export function getPublicImageUrl(
  supabase: Pick<SupabaseClient<Database>, 'storage'>,
  path: string | null,
): string | null {
  if (!path || isAbsoluteUrl(path)) return path;

  const bucket =
    process.env.SUPABASE_PUBLIC_IMAGE_BUCKET?.trim() ||
    DEFAULT_PUBLIC_IMAGE_BUCKET;
  const objectPath = path.replace(/^\/+/, '');

  return supabase.storage.from(bucket).getPublicUrl(objectPath).data.publicUrl;
}
