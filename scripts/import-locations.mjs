#!/usr/bin/env node

/**
 * Imports the pinned Countries States Cities Database release into app.countries
 * and app.cities. Apply 20260828100000_add_location_autocomplete.sql first.
 *
 * Required environment variables unless --dry-run is used:
 *   NEXT_PUBLIC_SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional arguments:
 *   --file=/path/to/json-countries+states+cities.json.gz
 *   --dry-run
 */
import { createClient } from '@supabase/supabase-js';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';

const SOURCE_VERSION = 'v3.2-export.7';
const SOURCE_URL =
  'https://github.com/dr5hn/countries-states-cities-database/releases/download/' +
  `${SOURCE_VERSION}/json-countries%2Bstates%2Bcities.json.gz`;
const SOURCE_SHA256 =
  '47d2c820d22dec315d797e1581a492794c23045acd1569ca0768632204335020';
const BATCH_SIZE = 500;

function argument(name) {
  return process.argv
    .find((value) => value.startsWith(`--${name}=`))
    ?.slice(name.length + 3);
}

function hasFlag(name) {
  return process.argv.includes(`--${name}`);
}

async function loadSource() {
  const file = argument('file');
  if (file) return readFile(file);

  const response = await fetch(SOURCE_URL);
  if (!response.ok) {
    throw new Error(
      `Unable to download location data: ${response.status} ${response.statusText}`,
    );
  }
  return Buffer.from(await response.arrayBuffer());
}

function verifySource(buffer) {
  const checksum = createHash('sha256').update(buffer).digest('hex');
  if (checksum !== SOURCE_SHA256) {
    throw new Error(
      `Location-data checksum mismatch. Expected ${SOURCE_SHA256}, received ${checksum}.`,
    );
  }
}

function requiredString(value, field, context) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Missing ${field} for ${context}.`);
  }
  return value;
}

function coordinate(value, field, context) {
  const parsed = Number.parseFloat(value);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Invalid ${field} for ${context}.`);
  }
  return parsed;
}

function normalizeDataset(dataset) {
  if (!Array.isArray(dataset)) {
    throw new Error('The location-data root must be an array of countries.');
  }

  const countries = [];
  const cities = [];
  const sourceIds = new Set();

  for (const country of dataset) {
    const code = requiredString(country.iso2, 'iso2', 'country').toUpperCase();
    const countryName = requiredString(country.name, 'name', code);
    if (code.length !== 2) {
      throw new Error(`Invalid ISO2 country code: ${code}.`);
    }

    countries.push({
      code,
      name: countryName,
      latitude: coordinate(country.latitude, 'latitude', code),
      longitude: coordinate(country.longitude, 'longitude', code),
      is_active: true,
    });

    if (!Array.isArray(country.states)) {
      throw new Error(`Missing states array for ${code}.`);
    }

    for (const state of country.states) {
      const regionName = requiredString(state.name, 'state name', code);
      if (!Array.isArray(state.cities)) {
        throw new Error(`Missing cities array for ${regionName}, ${code}.`);
      }

      for (const city of state.cities) {
        const sourceId = city.id;
        const context = `${city.name ?? 'unknown city'}, ${regionName}, ${code}`;
        if (!Number.isSafeInteger(sourceId) || sourceId <= 0) {
          throw new Error(`Invalid city source ID for ${context}.`);
        }
        if (sourceIds.has(sourceId)) {
          throw new Error(`Duplicate city source ID ${sourceId}.`);
        }
        sourceIds.add(sourceId);

        cities.push({
          source_id: sourceId,
          country_code: code,
          name: requiredString(city.name, 'city name', context),
          region_name: regionName,
          latitude: coordinate(city.latitude, 'latitude', context),
          longitude: coordinate(city.longitude, 'longitude', context),
          timezone: requiredString(city.timezone, 'timezone', context),
          is_active: true,
        });
      }
    }
  }

  return { countries, cities };
}

async function upsert(client, table, rows, onConflict) {
  for (let start = 0; start < rows.length; start += BATCH_SIZE) {
    const batch = rows.slice(start, start + BATCH_SIZE);
    const { error } = await client
      .schema('app')
      .from(table)
      .upsert(batch, { onConflict });
    if (error) {
      throw new Error(
        `Unable to import ${table} rows ${start + 1}-${start + batch.length}: ${error.message}`,
      );
    }

    if (table === 'cities' && (start + batch.length) % 10_000 === 0) {
      console.log(`Imported ${start + batch.length} of ${rows.length} cities.`);
    }
  }
}

async function main() {
  console.log(
    `Loading Countries States Cities Database ${SOURCE_VERSION} (ODbL v1.0).`,
  );
  const compressed = await loadSource();
  verifySource(compressed);
  const dataset = JSON.parse(gunzipSync(compressed).toString('utf8'));
  const { countries, cities } = normalizeDataset(dataset);

  console.log(
    `Validated ${countries.length} countries and ${cities.length} cities.`,
  );
  if (hasFlag('dry-run')) return;

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error(
      'NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.',
    );
  }

  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  await upsert(client, 'countries', countries, 'code');
  await upsert(client, 'cities', cities, 'source_id');
  console.log('Location import complete.');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
