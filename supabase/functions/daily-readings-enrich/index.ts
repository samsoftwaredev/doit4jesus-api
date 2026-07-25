import { createClient } from 'npm:@supabase/supabase-js@2';

import {
  parseScriptureReference,
  stripMarkup,
  type ScriptureReference,
} from '../_shared/daily-readings.ts';

const BIBLE_API_URL = 'https://thedouayrheims.com/api';

type ChapterResponse = {
  chapter: number;
  verses: Array<{ verse: number; text: string }>;
};

type StoredScriptureText = ScriptureReference & {
  text: string | null;
  error?: string;
};

function requireServiceAuthorization(request: Request) {
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = request.headers.get('authorization');

  if (!serviceRoleKey || authorization !== `Bearer ${serviceRoleKey}`) {
    throw new Response('Unauthorized', { status: 401 });
  }

  return serviceRoleKey;
}

function isReadingDate(value: unknown): value is string {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

async function getChapter(
  bookSlug: string,
  chapter: number,
  cache: Map<string, ChapterResponse>,
): Promise<ChapterResponse> {
  const cacheKey = `${bookSlug}:${chapter}`;
  const cached = cache.get(cacheKey);
  if (cached) return cached;

  const response = await fetch(
    `${BIBLE_API_URL}/chapter/${encodeURIComponent(bookSlug)}/${chapter}`,
    { headers: { Accept: 'application/json' } },
  );
  if (!response.ok) {
    throw new Error(`Scripture text request failed with ${response.status}.`);
  }

  const chapterResponse = (await response.json()) as ChapterResponse;
  cache.set(cacheKey, chapterResponse);
  return chapterResponse;
}

async function resolveScriptureText(
  scriptureReference: ScriptureReference,
  chapterCache: Map<string, ChapterResponse>,
): Promise<StoredScriptureText> {
  try {
    const parsed = parseScriptureReference(scriptureReference.reference);
    if (!parsed) throw new Error('The Scripture reference could not be parsed.');

    const selectedVerses: Array<{ chapter: number; verse: number; text: string }> = [];
    const seenVerses = new Set<string>();

    for (const range of parsed.ranges) {
      for (let chapter = range.startChapter; chapter <= range.endChapter; chapter += 1) {
        const chapterData = await getChapter(parsed.bookSlug, chapter, chapterCache);
        const firstVerse = chapter === range.startChapter ? range.startVerse : 1;
        const lastVerse = chapter === range.endChapter ? range.endVerse : Infinity;

        for (const verse of chapterData.verses) {
          if (verse.verse < firstVerse || verse.verse > lastVerse) continue;
          const key = `${chapter}:${verse.verse}`;
          if (seenVerses.has(key)) continue;
          seenVerses.add(key);
          selectedVerses.push({
            chapter,
            verse: verse.verse,
            text: stripMarkup(verse.text),
          });
        }
      }
    }

    if (selectedVerses.length === 0) {
      throw new Error('No verses were returned for the Scripture reference.');
    }

    return {
      ...scriptureReference,
      text: selectedVerses
        .map((verse) => `${verse.chapter}:${verse.verse} ${verse.text}`)
        .join('\n'),
    };
  } catch (error) {
    return {
      ...scriptureReference,
      text: null,
      error: error instanceof Error ? error.message : 'Scripture text lookup failed.',
    };
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method Not Allowed', {
      status: 405,
      headers: { Allow: 'POST' },
    });
  }

  try {
    const serviceRoleKey = requireServiceAuthorization(request);
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    if (!supabaseUrl) throw new Error('SUPABASE_URL is not configured.');

    const body = await request.json().catch(() => ({}));
    const readingDates = Array.isArray(body.readingDates)
      ? body.readingDates.filter(isReadingDate)
      : [];
    if (readingDates.length === 0) {
      return Response.json({ enriched: 0, message: 'No reading dates supplied.' });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: rows, error } = await supabase
      .schema('prayer')
      .from('daily_readings')
      .select('id, scripture_references')
      .in('reading_date', readingDates);
    if (error) throw new Error(`Unable to load daily readings: ${error.message}`);

    const chapterCache = new Map<string, ChapterResponse>();
    let enriched = 0;

    for (const row of rows ?? []) {
      const references = Array.isArray(row.scripture_references)
        ? (row.scripture_references as ScriptureReference[])
        : [];
      const scriptureText = await Promise.all(
        references.map((reference) => resolveScriptureText(reference, chapterCache)),
      );
      const successfulCount = scriptureText.filter((entry) => entry.text !== null).length;
      const textStatus =
        successfulCount === scriptureText.length
          ? 'complete'
          : successfulCount > 0
            ? 'partial'
            : 'failed';

      const { error: updateError } = await supabase
        .schema('prayer')
        .from('daily_readings')
        .update({ scripture_text: scriptureText, text_status: textStatus })
        .eq('id', row.id);
      if (updateError) {
        throw new Error(`Unable to save Scripture text: ${updateError.message}`);
      }

      enriched += 1;
    }

    return Response.json({ enriched });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error('daily-readings-enrich failed', error);
    return Response.json(
      { error: error instanceof Error ? error.message : 'Enrichment failed.' },
      { status: 500 },
    );
  }
});
