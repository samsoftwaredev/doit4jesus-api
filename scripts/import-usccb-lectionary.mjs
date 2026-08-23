#!/usr/bin/env node

/**
 * Imports licensed USCCB daily-reading metadata into a checked-in local JSON
 * snapshot. This is intentionally a development command: production requests
 * never call USCCB.
 *
 * Examples:
 *   pnpm import:usccb-lectionary -- --year=2026
 *   pnpm import:usccb-lectionary -- --from=2026-08-22 --to=2026-12-31
 *   pnpm import:usccb-lectionary -- --input-html=/path/to/page.html --date=2026-11-02
 */
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const OUTPUT_PATH = resolve('src/liturgy/data/lectionary/usccb.json');
const USER_AGENT =
  'DoIt4Jesus-USCCB-Lectionary-Importer/1.0 (licensed dataset import)';
const REQUEST_DELAY_MILLISECONDS = 850;
const MAX_ATTEMPTS = 4;

const readingTypeByHeading = {
  'reading 1': 'FIRST_READING',
  'first reading': 'FIRST_READING',
  'responsorial psalm': 'RESPONSORIAL_PSALM',
  'reading 2': 'SECOND_READING',
  'second reading': 'SECOND_READING',
  epistle: 'EPISTLE',
  alleluia: 'GOSPEL_ACCLAMATION',
  'gospel acclamation': 'GOSPEL_ACCLAMATION',
  gospel: 'GOSPEL',
};

function sleep(milliseconds) {
  return new Promise((resolveSleep) => setTimeout(resolveSleep, milliseconds));
}

function stripHtml(value) {
  return value
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&quot;/gi, '"')
    .replace(/&[a-z]+;/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function slug(value) {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function dateUrl(date) {
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  const year = String(date.getUTCFullYear()).slice(-2);
  return `https://bible.usccb.org/bible/readings/${month}${day}${year}.cfm`;
}

function inferGrade(name) {
  if (/^solemnity\b/i.test(name)) return 'SOLEMNITY';
  if (/^feast\b/i.test(name)) return 'FEAST';
  if (/^memorial\b/i.test(name)) return 'MEMORIAL';
  if (/\bsunday\b/i.test(name)) return 'SUNDAY';
  return 'WEEKDAY';
}

function inferColors(name) {
  if (/martyr|passion|palm sunday|pentecost/i.test(name)) return ['RED'];
  if (/advent|lent|ash wednesday/i.test(name)) return ['VIOLET'];
  if (/ordinary time/i.test(name)) return ['GREEN'];
  return ['WHITE'];
}

function readingSetsFromHtml(html, date) {
  const sections = [
    ...html.matchAll(/<h2[^>]*>([\s\S]*?)<\/h2>([\s\S]*?)(?=<h2[^>]*>|$)/gi),
  ];
  const candidates = sections.length > 0 ? sections : [[null, '', html]];
  const readingSets = [];

  for (const [, headingHtml, sectionHtml] of candidates) {
    const readings = [];
    const readingBlocks = sectionHtml.matchAll(
      /<h3[^>]*class="name"[^>]*>([\s\S]*?)<\/h3>[\s\S]*?<div[^>]*class="address"[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/gi,
    );
    for (const [, heading, citation] of readingBlocks) {
      const type =
        readingTypeByHeading[stripHtml(heading).toLowerCase()] ?? 'OTHER';
      readings.push({ type, citation: stripHtml(citation) });
    }
    if (readings.length === 0) continue;

    const label = /vigil/i.test(stripHtml(headingHtml)) ? 'VIGIL' : 'DEFAULT';
    readingSets.push({
      id: `usccb-${date}-${slug(stripHtml(headingHtml)) || 'default'}`,
      label,
      selectionRule: 'REQUIRED_PROPER',
      readings,
    });
  }

  return readingSets;
}

export function parseUsccbDailyPage(html, date, sourceUrl) {
  const titleMatch = html.match(
    /<meta\s+property="og:title"\s+content="([^"]+)"\s*\/>/i,
  );
  const name = stripHtml(titleMatch?.[1] ?? '').replace(/\s*\|\s*USCCB$/, '');
  const lectionaryNumber = html.match(
    /Lectionary:\s*(?:<[^>]+>\s*)*(\d+)/i,
  )?.[1];
  const readingSets = readingSetsFromHtml(html, date);

  if (!name || readingSets.length === 0) {
    throw new Error(
      `USCCB page for ${date} did not contain readable lectionary metadata.`,
    );
  }

  return {
    date,
    celebration: {
      id: slug(name),
      name,
      grade: inferGrade(name),
      colors: inferColors(name),
      readingSelectionRule: 'REQUIRED_PROPER',
    },
    ...(lectionaryNumber ? { lectionaryNumber } : {}),
    readingSets,
    sourceUrl,
  };
}

async function fetchPage(url) {
  let lastError;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: 'text/html,application/xhtml+xml',
          'User-Agent': USER_AGENT,
        },
      });
      if (!response.ok) {
        throw new Error(`${response.status} ${response.statusText}`);
      }
      return await response.text();
    } catch (error) {
      lastError = error;
      if (attempt < MAX_ATTEMPTS) await sleep(1_000 * 2 ** (attempt - 1));
    }
  }
  throw new Error(`Unable to fetch ${url}: ${String(lastError)}`);
}

function argument(name) {
  return process.argv
    .find((value) => value.startsWith(`--${name}=`))
    ?.slice(name.length + 3);
}

function parseDate(value, name) {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(`${name} must use YYYY-MM-DD.`);
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (date.toISOString().slice(0, 10) !== value) {
    throw new Error(`${name} must be a real calendar date.`);
  }
  return date;
}

function datesBetween(start, end) {
  const dates = [];
  for (
    let date = new Date(start);
    date <= end;
    date.setUTCDate(date.getUTCDate() + 1)
  ) {
    dates.push(new Date(date));
  }
  return dates;
}

async function main() {
  const year = argument('year');
  const existing = JSON.parse(await readFile(OUTPUT_PATH, 'utf8'));
  const byDate = new Map(existing.map((record) => [record.date, record]));
  const records = [];

  const inputHtml = argument('input-html');
  if (inputHtml) {
    const date = parseDate(argument('date'), '--date');
    const dateKey = date.toISOString().slice(0, 10);
    const sourceUrl = argument('source-url') ?? dateUrl(date);
    const html = await readFile(resolve(inputHtml), 'utf8');
    records.push(parseUsccbDailyPage(html, dateKey, sourceUrl));
  } else {
    const start = parseDate(
      argument('from') ?? (year ? `${year}-01-01` : ''),
      '--from',
    );
    const end = parseDate(
      argument('to') ?? (year ? `${year}-12-31` : ''),
      '--to',
    );
    if (end < start) throw new Error('--to must be on or after --from.');

    for (const date of datesBetween(start, end)) {
      const dateKey = date.toISOString().slice(0, 10);
      const sourceUrl = dateUrl(date);
      console.log(`Importing ${dateKey}`);
      const html = await fetchPage(sourceUrl);
      records.push(parseUsccbDailyPage(html, dateKey, sourceUrl));
      await sleep(REQUEST_DELAY_MILLISECONDS);
    }
  }

  for (const record of records) byDate.set(record.date, record);
  const sorted = [...byDate.values()].sort((left, right) =>
    left.date.localeCompare(right.date),
  );
  await writeFile(OUTPUT_PATH, `${JSON.stringify(sorted, null, 2)}\n`);
  console.log(`Wrote ${records.length} USCCB records to ${OUTPUT_PATH}.`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
