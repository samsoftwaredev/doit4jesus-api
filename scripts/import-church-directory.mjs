#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const CONFIRMATION = 'IMPORT_CHURCH_DIRECTORY';
const LOCAL_DATABASE_URL =
  'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
const SCRIPT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const REPOSITORY_ROOT = resolve(SCRIPT_DIRECTORY, '..');
const SQL_TEMPLATE = resolve(SCRIPT_DIRECTORY, 'import-church-directory.sql');
const INPUTS = {
  churches: {
    path: resolve(REPOSITORY_ROOT, 'src/data/churches_all_candidates.csv'),
    sha256: 'e95ed31702f53da843bcc8dd3382338f819daea78570d76cf5a7899d1d89b4e4',
    rows: 24_145,
    header:
      'church_id,church_name,church_address,street_address,city,state,zip_code,diocese,latitude,longitude,diocese_status,record_status,review_reasons,source,source_id,source_release,source_category,source_confidence',
  },
  postal: {
    path: resolve(REPOSITORY_ROOT, 'src/data/zip_city_diocese_timezone.csv'),
    sha256: 'd55051b7cc8ac8cc1c4f6e79a2ca32062c836f0b982b064f61a5909201ab9d29',
    rows: 57_918,
    header:
      'zip_code,city,city_label,city_geoid,city_state,city_overlap_percent,city_status,latitude,longitude,centroid_county,centroid_state,diocese,candidate_dioceses,diocese_status,timezone,timezone_candidates,timezone_status,zcta_source_year,city_source_year,diocese_source_year,timezone_source_release',
  },
};

function usage() {
  return `Usage:
  npm run import:church-directory -- [--database-url=postgresql://...]
  npm run import:church-directory -- --apply --confirm=${CONFIRMATION} [--database-url=...]

Preview is the default and rolls back the import transaction. The database URL
may instead be supplied through CHURCH_DIRECTORY_DATABASE_URL (also read from
.env). When neither is set, the local Supabase database is used.`;
}

function parseArguments(values) {
  const options = new Map();
  const flags = new Set();
  for (const value of values) {
    if (!value.startsWith('--'))
      throw new Error(`Unexpected argument: ${value}`);
    const separator = value.indexOf('=');
    if (separator === -1) flags.add(value.slice(2));
    else options.set(value.slice(2, separator), value.slice(separator + 1));
  }
  for (const name of options.keys()) {
    if (!['database-url', 'confirm'].includes(name))
      throw new Error(`Unknown option: --${name}`);
  }
  for (const name of flags) {
    if (!['apply', 'help'].includes(name))
      throw new Error(`Unknown flag: --${name}`);
  }
  return { options, flags };
}

async function sha256(path) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest('hex');
}

async function validateInput(input) {
  const [digest, contents] = await Promise.all([
    sha256(input.path),
    readFile(input.path, 'utf8'),
  ]);
  if (digest !== input.sha256)
    throw new Error(`Unexpected SHA-256 for ${input.path}: ${digest}`);
  const firstNewline = contents.indexOf('\n');
  const header = contents.slice(0, firstNewline).replace(/\r$/, '');
  if (header !== input.header)
    throw new Error(`Unexpected CSV header for ${input.path}`);
  const rows = contents.split('\n').length - (contents.endsWith('\n') ? 2 : 1);
  if (rows !== input.rows)
    throw new Error(
      `Expected ${input.rows} rows in ${input.path}, found ${rows}`,
    );
}

function psqlPath(path) {
  return `'${path.replaceAll("'", "''")}'`;
}

async function runPsql(databaseUrl, sqlPath) {
  await new Promise((resolvePromise, reject) => {
    const child = spawn(
      'psql',
      [databaseUrl, '-X', '-v', 'ON_ERROR_STOP=1', '-f', sqlPath],
      {
        stdio: 'inherit',
      },
    );
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) resolvePromise();
      else reject(new Error(`psql exited with status ${code}`));
    });
  });
}

const { options, flags } = parseArguments(process.argv.slice(2));
if (flags.has('help')) {
  console.log(usage());
  process.exit(0);
}
const apply = flags.has('apply');
if (apply && options.get('confirm') !== CONFIRMATION) {
  throw new Error(`Apply mode requires --confirm=${CONFIRMATION}`);
}
const databaseUrl =
  options.get('database-url') ||
  process.env.CHURCH_DIRECTORY_DATABASE_URL ||
  LOCAL_DATABASE_URL;
console.log(
  databaseUrl === LOCAL_DATABASE_URL
    ? 'Using the local Supabase database.'
    : 'Using the configured database URL.',
);

await Promise.all(Object.values(INPUTS).map(validateInput));
const template = await readFile(SQL_TEMPLATE, 'utf8');
const sql = template
  .replaceAll('__CHURCHES_CSV__', psqlPath(INPUTS.churches.path))
  .replaceAll('__POSTAL_CSV__', psqlPath(INPUTS.postal.path))
  .replaceAll('__FINALIZE__', apply ? 'commit;' : 'rollback;');
const temporaryDirectory = await mkdtemp(
  resolve(tmpdir(), 'church-directory-import-'),
);
const sqlPath = resolve(temporaryDirectory, 'import.sql');
try {
  await writeFile(sqlPath, sql, { mode: 0o600 });
  await runPsql(databaseUrl, sqlPath);
  console.log(
    apply
      ? 'Church directory import applied.'
      : 'Church directory preview passed and was rolled back.',
  );
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}
