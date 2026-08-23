#!/usr/bin/env node

/**
 * Converts text extracted from the licensed USCCB annual Liturgical Calendar
 * into the checked-in local U.S. lectionary snapshot. The production API reads
 * only that snapshot; it never makes a request to USCCB.
 *
 * The USCCB calendar supplies the observance and its Scripture citations for
 * every date. It intentionally does not print responsorial-psalm citations, so
 * a richer daily USCCB record already in the snapshot always takes precedence.
 *
 * Extract the source with a local PDF-text tool, then run:
 *   pnpm import:usccb-calendar -- --input=/path/to/2026cal.txt --year=2026
 */
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const OUTPUT_PATH = resolve('src/liturgy/data/lectionary/usccb.json');
const USCCB_CALENDAR_URL = 'https://www.usccb.org/resources/2026cal.pdf';

const MONTHS = new Map(
  [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ].map((name, index) => [name, index + 1]),
);

const COLORS = new Map([
  ['white', 'WHITE'],
  ['green', 'GREEN'],
  ['violet', 'VIOLET'],
  ['red', 'RED'],
  ['rose', 'ROSE'],
]);

const BOOK = String.raw`(?:[1-3]\s*)?(?:Acts|Am|Bar|Col|Cor|Dn|Dt|Eccl|Eph|Est|Ex|Ez|Gal|Gn|Hb|Heb|Hos|Is|Jas|Jer|Jgs|Jl|Jn|Job|Jon|Jos|Jude|Lam|Lk|Lv|Mal|Mc|Mk|Mt|Nm|Ob|Phil|Phlm|Prv|Pt|Rom|Rv|Ru|Sg|Sir|Sm|Tb|Thes|Ti|Tm|Wis|Zec|Zep|Kgs|Chr)`;
const CITATION = new RegExp(
  String.raw`(?:(Vigil|Night|Dawn|Day|Extended Vigil|Chrism Mass|Evening Mass of the Lord's Supper|Easter Vigil)\s*:\s*)?((?:${BOOK})\s+\d[\s\S]*?)\s*\((\d+[A-Z]?)\)`,
  'gi',
);
const DATE = /^(\d{1,2})\s+(SUN|Mon|Tue|Wed|Thu|Fri|Sat)\s+/gm;

function argument(name) {
  return process.argv
    .find((value) => value.startsWith(`--${name}=`))
    ?.slice(name.length + 3);
}

function slug(value) {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function normalizeWhitespace(value) {
  return value.replace(/\s+/g, ' ').trim();
}

function inferGrade(value) {
  if (/\bsolemnity\b/i.test(value)) return 'SOLEMNITY';
  if (/\bfeast\b/i.test(value)) return 'FEAST';
  if (/\bmemorial\b/i.test(value)) return 'MEMORIAL';
  if (/\bSUN\b|\bsunday\b/i.test(value)) return 'SUNDAY';
  return 'WEEKDAY';
}

function calendarColors(value) {
  const colors = [
    ...value.toLowerCase().matchAll(/\b(white|green|violet|red|rose)\b/g),
  ]
    .map((match) => COLORS.get(match[1]))
    .filter(Boolean);
  return [...new Set(colors)].length > 0 ? [...new Set(colors)] : ['WHITE'];
}

function cleanCitation(value) {
  return normalizeWhitespace(value)
    .replace(/\s+Pss\s+(?:Prop|[IV]+)/gi, '')
    .replace(/\s+or\s+.+$/i, '')
    .trim();
}

function readingsFromCitation(citation) {
  const parts = citation
    .split('/')
    .map((part) => cleanCitation(part))
    .filter(Boolean);

  return parts.map((part, index) => {
    let type = 'OTHER';
    if (parts.length === 1) type = 'GOSPEL';
    else if (parts.length === 2)
      type = index === 0 ? 'FIRST_READING' : 'GOSPEL';
    else if (index === parts.length - 1) type = 'GOSPEL';
    else if (index === parts.length - 2) type = 'SECOND_READING';
    else if (index === 0) type = 'FIRST_READING';
    return { type, citation: part };
  });
}

function labelFor(value) {
  switch (value?.toLowerCase()) {
    case 'vigil':
      return 'VIGIL';
    case 'night':
      return 'NIGHT';
    case 'dawn':
      return 'DAWN';
    case 'day':
      return 'DAY';
    case 'extended vigil':
      return 'EXTENDED_VIGIL';
    default:
      return 'DEFAULT';
  }
}

function celebrationName(header, fallback) {
  return (
    normalizeWhitespace(header)
      .replace(/^\d{1,2}\s+(?:SUN|Mon|Tue|Wed|Thu|Fri|Sat)\s+/i, '')
      .replace(
        /\b(?:white|green|violet|red|rose)\b(?:\s+or\s+\b(?:white|green|violet|red|rose)\b)*/gi,
        '',
      )
      .replace(/\b(?:Solemnity|Feast|Memorial)(?:\s*\[[^\]]+\])?/gi, '')
      .replace(/\b(?:Solemnity|Feast|Memorial)\b/gi, '')
      .replace(/\d+(?=\s*$)/, '')
      .replace(/\s{2,}/g, ' ')
      .trim() || fallback
  );
}

function parseRecord(content, month, year) {
  const dateMatch = content.match(
    /^(\d{1,2})\s+(SUN|Mon|Tue|Wed|Thu|Fri|Sat)\s+/i,
  );
  if (!dateMatch || !month) return undefined;
  const day = Number.parseInt(dateMatch[1], 10);
  const date = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const matches = [...content.matchAll(CITATION)];
  if (matches.length === 0) return undefined;

  const header = content.slice(0, matches[0].index);
  const name = celebrationName(header, `Liturgical observance on ${date}`);
  const readingSets = matches.map((match, index) => ({
    id: `usccb-${date}-${slug(match[1] ?? `set-${index + 1}`)}`,
    label: labelFor(match[1]),
    selectionRule: 'REQUIRED_PROPER',
    readings: readingsFromCitation(match[2]),
  }));

  return {
    date,
    celebration: {
      id: slug(name),
      name,
      grade: inferGrade(header),
      colors: calendarColors(header),
      readingSelectionRule: 'REQUIRED_PROPER',
    },
    lectionaryNumber: matches[0][3],
    readingSets,
    sourceUrl: USCCB_CALENDAR_URL,
  };
}

function parseCalendar(text, year) {
  const matches = [...text.matchAll(DATE)];
  let month;
  const records = [];
  for (let index = 0; index < matches.length; index += 1) {
    const start = matches[index].index;
    const previous = text.slice(Math.max(0, start - 120), start);
    const monthMatch = [
      ...previous.matchAll(
        /\b(JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+(\d{4})\b/g,
      ),
    ].pop();
    if (monthMatch && Number.parseInt(monthMatch[2], 10) === year) {
      month = MONTHS.get(monthMatch[1]);
    }
    const record = parseRecord(
      text.slice(start, matches[index + 1]?.index),
      month,
      year,
    );
    if (record) records.push(record);
  }
  return records;
}

function isRichDailyRecord(record) {
  return record?.sourceUrl?.startsWith(
    'https://bible.usccb.org/bible/readings/',
  );
}

async function main() {
  const input = argument('input');
  const yearValue = argument('year');
  const year = Number.parseInt(yearValue ?? '', 10);
  if (!input)
    throw new Error('--input must point to extracted USCCB calendar text.');
  if (!Number.isInteger(year) || year < 2000 || year > 2100) {
    throw new Error('--year must be a four-digit calendar year.');
  }

  const [text, existingText] = await Promise.all([
    readFile(resolve(input), 'utf8'),
    readFile(OUTPUT_PATH, 'utf8'),
  ]);
  const imported = parseCalendar(text, year);
  if (new Set(imported.map((record) => record.date)).size < 364) {
    throw new Error(
      `Expected a full ${year} calendar, but found only ${imported.length} dated entries.`,
    );
  }

  const byDate = new Map(
    JSON.parse(existingText).map((record) => [record.date, record]),
  );
  for (const record of imported) {
    if (!isRichDailyRecord(byDate.get(record.date)))
      byDate.set(record.date, record);
  }
  const sorted = [...byDate.values()].sort((left, right) =>
    left.date.localeCompare(right.date),
  );
  await writeFile(OUTPUT_PATH, `${JSON.stringify(sorted, null, 2)}\n`);
  console.log(
    `Wrote ${imported.length} USCCB ${year} calendar records to ${OUTPUT_PATH}.`,
  );
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

export { parseCalendar };
