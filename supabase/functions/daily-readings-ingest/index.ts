import { createClient } from 'npm:@supabase/supabase-js@2';

import {
  extractLectionaryNumber,
  parseDailyReadingsFeed,
} from '../_shared/daily-readings.ts';

const FEED_URL = 'https://bible.usccb.org/readings.rss';
const ENRICHMENT_FUNCTION = 'daily-readings-enrich';

function requireServiceAuthorization(request: Request) {
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authorization = request.headers.get('authorization');

  if (!serviceRoleKey || authorization !== `Bearer ${serviceRoleKey}`) {
    throw new Response('Unauthorized', { status: 401 });
  }

  return serviceRoleKey;
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

    const feedResponse = await fetch(FEED_URL, {
      headers: { Accept: 'application/rss+xml, application/xml, text/xml' },
    });
    if (!feedResponse.ok) {
      throw new Error(`Unable to fetch daily readings: ${feedResponse.status}.`);
    }

    const feedReadings = parseDailyReadingsFeed(await feedResponse.text());
    if (feedReadings.length === 0) {
      throw new Error('The daily readings feed did not contain any usable entries.');
    }

    const records = await Promise.all(
      feedReadings.map(async (reading) => {
        const pageResponse = await fetch(reading.dailyReadingUrl, {
          headers: { Accept: 'text/html' },
        });
        const lectionaryNumber = pageResponse.ok
          ? extractLectionaryNumber(await pageResponse.text())
          : null;

        return {
          reading_date: reading.readingDate,
          celebration_name: reading.celebrationName,
          lectionary_number: lectionaryNumber,
          scripture_references: reading.scriptureReferences,
          text_status: 'pending',
        };
      }),
    );

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const readingDates = records.map((record) => record.reading_date);
    const { data: existingRows, error: existingRowsError } = await supabase
      .schema('prayer')
      .from('daily_readings')
      .select('reading_date, scripture_references, text_status')
      .in('reading_date', readingDates);
    if (existingRowsError) {
      throw new Error(`Unable to load daily readings: ${existingRowsError.message}`);
    }

    const existingByDate = new Map(
      (existingRows ?? []).map((row) => [
        row.reading_date,
        {
          references: JSON.stringify(row.scripture_references),
          textStatus: row.text_status,
        },
      ]),
    );
    const newRecords = records.filter(
      (record) => !existingByDate.has(record.reading_date),
    );
    const changedRecords = records.filter((record) => {
      const existing = existingByDate.get(record.reading_date);
      return (
        existing !== undefined &&
        existing.references !== JSON.stringify(record.scripture_references)
      );
    });

    if (newRecords.length > 0) {
      const { error: insertError } = await supabase
        .schema('prayer')
        .from('daily_readings')
        .upsert(newRecords, { onConflict: 'reading_date' });
      if (insertError) {
        throw new Error(`Unable to save daily readings: ${insertError.message}`);
      }
    }

    await Promise.all(
      records
        .filter((record) => existingByDate.has(record.reading_date))
        .map(async (record) => {
          const hasChangedReferences = changedRecords.some(
            (changedRecord) => changedRecord.reading_date === record.reading_date,
          );
          const { error: updateError } = await supabase
            .schema('prayer')
            .from('daily_readings')
            .update({
              celebration_name: record.celebration_name,
              lectionary_number: record.lectionary_number,
              scripture_references: record.scripture_references,
              ...(hasChangedReferences
                ? { scripture_text: [], text_status: 'pending' }
                : {}),
            })
            .eq('reading_date', record.reading_date);
          if (updateError) {
            throw new Error(`Unable to update daily readings: ${updateError.message}`);
          }
        }),
    );

    const readingDatesToEnrich = [...new Set([
      ...newRecords.map((record) => record.reading_date),
      ...changedRecords.map((record) => record.reading_date),
      ...records
        .filter(
          (record) =>
            existingByDate.get(record.reading_date)?.textStatus !== 'complete',
        )
        .map((record) => record.reading_date),
    ])];

    if (readingDatesToEnrich.length > 0) {
      const enrichmentResponse = await fetch(
        `${supabaseUrl}/functions/v1/${ENRICHMENT_FUNCTION}`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${serviceRoleKey}`,
            apikey: serviceRoleKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ readingDates: readingDatesToEnrich }),
        },
      );
      if (!enrichmentResponse.ok) {
        throw new Error(
          `Daily-reading enrichment failed: ${enrichmentResponse.status}.`,
        );
      }
    }

    return Response.json({
      imported: records.length,
      enriched: readingDatesToEnrich.length,
      readingDates,
    });
  } catch (error) {
    if (error instanceof Response) return error;
    console.error('daily-readings-ingest failed', error);
    return Response.json(
      { error: error instanceof Error ? error.message : 'Import failed.' },
      { status: 500 },
    );
  }
});
