#!/usr/bin/env node

/**
 * Builds the runtime username-moderation dataset from the checked-in English
 * and Spanish sources plus a pinned LDNOOBW revision.
 *
 * Optional offline inputs:
 *   --ldnoobw-en=/path/to/en
 *   --ldnoobw-es=/path/to/es
 */
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const OUTPUT_PATH = resolve('src/data/username-prohibited-terms.json');
const LOCAL_EN_PATH = resolve('src/data/profanity_en.csv');
const LOCAL_ES_PATH = resolve('src/data/profanity_es.csv');
const LDNOOBW_COMMIT = '5faf2ba42d7b1c0977169ec3611df25a3c08eb13';
const LDNOOBW = {
  en: {
    sha256: 'af851ecef1d5f212caba17339b12ac39cc2fef7d78c74876f67237644fcee8bd',
    url: `https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/${LDNOOBW_COMMIT}/en`,
  },
  es: {
    sha256: '073334261cc2e7c08339faefd2f19f9623e8240a0ac18fe2a26c368b897496ce',
    url: `https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/${LDNOOBW_COMMIT}/es`,
  },
};

// Only high-confidence roots belong here. Broad substring matching on every
// source word creates false positives such as "Cassidy" ("ass") and
// "Scunthorpe" ("cunt"). All source entries are still checked as exact
// username tokens below.
const SUBSTRING_TERMS = [
  'blowjob',
  'chupapollas',
  'faggot',
  'fck',
  'fuck',
  'fuk',
  'fvck',
  'gilipollas',
  'hijoputa',
  'masturbat',
  'mierda',
  'motherfucker',
  'nigga',
  'nigger',
  'pedophile',
  'pendej',
  'pussy',
  'soplapollas',
];

function argument(name) {
  return process.argv
    .find((value) => value.startsWith(`--${name}=`))
    ?.slice(name.length + 3);
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function normalizeTerm(value) {
  const leetMap = new Map([
    ['0', 'o'],
    ['1', 'i'],
    ['3', 'e'],
    ['4', 'a'],
    ['5', 's'],
    ['6', 'g'],
    ['7', 't'],
    ['8', 'b'],
    ['9', 'g'],
  ]);

  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .split('')
    .map((character) => leetMap.get(character) ?? character)
    .join('')
    .replace(/[^a-z0-9]/g, '');
}

function parseCsvLine(line) {
  const values = [];
  let value = '';
  let quoted = false;

  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    if (character === '"') {
      if (quoted && line[index + 1] === '"') {
        value += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (character === ',' && !quoted) {
      values.push(value);
      value = '';
    } else {
      value += character;
    }
  }
  values.push(value);
  return values;
}

function parseEnglishCsv(csv) {
  const lines = csv.replace(/\r/g, '').split('\n').filter(Boolean);
  const headers = parseCsvLine(lines.shift());
  const index = Object.fromEntries(
    headers.map((header, headerIndex) => [header, headerIndex]),
  );

  return lines.map((line) => {
    const fields = parseCsvLine(line);
    return {
      text: fields[index.text] ?? '',
      canonicalForms: [
        fields[index.canonical_form_1],
        fields[index.canonical_form_2],
        fields[index.canonical_form_3],
      ].filter(Boolean),
    };
  });
}

function lines(value) {
  return value
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

async function loadUpstream(language) {
  const localPath = argument(`ldnoobw-${language}`);
  const content = localPath
    ? await readFile(localPath, 'utf8')
    : await fetch(LDNOOBW[language].url).then(async (response) => {
        if (!response.ok) {
          throw new Error(
            `Unable to download LDNOOBW ${language}: ${response.status}.`,
          );
        }
        return response.text();
      });

  const checksum = sha256(content);
  if (checksum !== LDNOOBW[language].sha256) {
    throw new Error(
      `LDNOOBW ${language} checksum mismatch: received ${checksum}.`,
    );
  }
  return content;
}

function addExactTerm(target, value) {
  const normalized = normalizeTerm(value);
  if (normalized.length >= 3 && normalized.length <= 30) {
    target.add(normalized);
  }
}

async function main() {
  const [localEn, localEs, upstreamEn, upstreamEs] = await Promise.all([
    readFile(LOCAL_EN_PATH, 'utf8'),
    readFile(LOCAL_ES_PATH, 'utf8'),
    loadUpstream('en'),
    loadUpstream('es'),
  ]);
  const englishRows = parseEnglishCsv(localEn);
  const exactTerms = new Set();
  const substringTerms = new Set(SUBSTRING_TERMS.map(normalizeTerm));

  for (const row of englishRows) {
    addExactTerm(exactTerms, row.text);
    for (const canonicalForm of row.canonicalForms) {
      addExactTerm(exactTerms, canonicalForm);
    }
  }

  for (const term of [
    ...lines(localEs),
    ...lines(upstreamEn),
    ...lines(upstreamEs),
  ]) {
    addExactTerm(exactTerms, term);
  }

  const output = {
    metadata: {
      localEnglish: {
        path: 'src/data/profanity_en.csv',
        sha256: sha256(localEn),
      },
      localSpanish: {
        path: 'src/data/profanity_es.csv',
        sha256: sha256(localEs),
      },
      ldnoobw: {
        repository:
          'https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words',
        commit: LDNOOBW_COMMIT,
        license: 'CC-BY-4.0',
        enSha256: LDNOOBW.en.sha256,
        esSha256: LDNOOBW.es.sha256,
      },
    },
    exactTerms: [...exactTerms].sort(),
    substringTerms: [...substringTerms].sort(),
  };

  await writeFile(OUTPUT_PATH, `${JSON.stringify(output, null, 2)}\n`);
  console.log(
    `Wrote ${output.exactTerms.length} exact terms and ${output.substringTerms.length} substring roots to ${OUTPUT_PATH}.`,
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
