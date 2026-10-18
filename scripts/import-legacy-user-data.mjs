#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const CONFIRMATION = 'REPLACE_MATCHED_LEGACY_DATA';
const SCRIPT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const REPOSITORY_ROOT = resolve(SCRIPT_DIRECTORY, '..');
const SQL_TEMPLATE = resolve(SCRIPT_DIRECTORY, 'import-legacy-user-data.sql');
const USERNAME_PROHIBITED_TERMS = resolve(
  REPOSITORY_ROOT,
  'src/data/username-prohibited-terms.json',
);
const EXPECTED_INPUTS = {
  profiles: {
    sha256: 'ab5d4d91a2b9c72f467a60d50fb06f009b2e2e94a08c0e9cd814894c4596b4b9',
    token: '__PROFILES_CSV__',
  },
  'rosary-stats': {
    sha256: 'b94c0016ee4e0ea450d2f29f813dfb131cd5d8971cb4ff4478d8fd16caa73cf7',
    token: '__ROSARY_STATS_CSV__',
  },
  'user-xp': {
    sha256: '85b97cabeeeb3ef4593dc4e85169d9cfd80ccaf290441753168da00c570c7407',
    token: '__USER_XP_CSV__',
  },
};

function usage() {
  return `Usage:
  npm run import:legacy-user-data -- \\
    --profiles=/absolute/path/profiles_rows.csv \\
    --rosary-stats=/absolute/path/rosary_stats_rows.csv \\
    --user-xp=/absolute/path/user_xp_rows.csv \\
    [--database-url=postgresql://...]

Preview is the default. The database URL may instead be supplied through
LEGACY_IMPORT_DATABASE_URL.

Exercise the full replacement transaction locally and roll it back:
  --verify-local

Apply additionally requires:
  --apply
  --confirm=${CONFIRMATION}
  --backup-confirmed
  --backup-dir=/absolute/path/outside/the/repository
`;
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

  return { options, flags };
}

function validateArguments(options, flags) {
  const knownOptions = new Set([
    'profiles',
    'rosary-stats',
    'user-xp',
    'database-url',
    'confirm',
    'backup-dir',
  ]);
  const knownFlags = new Set([
    'help',
    'apply',
    'verify-local',
    'backup-confirmed',
  ]);
  for (const name of options.keys()) {
    if (!knownOptions.has(name)) throw new Error(`Unknown option: --${name}`);
  }
  for (const name of flags) {
    if (!knownFlags.has(name)) throw new Error(`Unknown flag: --${name}`);
  }
}

async function sha256(path) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest('hex');
}

function parseCsv(value) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;

  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];
    if (quoted) {
      if (character === '"' && value[index + 1] === '"') {
        field += '"';
        index += 1;
      } else if (character === '"') {
        quoted = false;
      } else {
        field += character;
      }
    } else if (character === '"') {
      quoted = true;
    } else if (character === ',') {
      row.push(field);
      field = '';
    } else if (character === '\n') {
      row.push(field.endsWith('\r') ? field.slice(0, -1) : field);
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += character;
    }
  }

  if (quoted) throw new Error('The profiles CSV contains an unclosed quote.');
  if (field || row.length) {
    row.push(field.endsWith('\r') ? field.slice(0, -1) : field);
    rows.push(row);
  }
  return rows;
}

function normalizeUsernameForModeration(value) {
  const leetCharacters = {
    0: 'o',
    1: 'i',
    3: 'e',
    4: 'a',
    5: 's',
    6: 'g',
    7: 't',
    8: 'b',
    9: 'g',
  };
  return value
    .normalize('NFKD')
    .replaceAll(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .split('')
    .map((character) => leetCharacters[character] ?? character)
    .join('')
    .replaceAll(/[^a-z0-9]/g, '');
}

function containsProhibitedTerm(username, prohibitedTerms) {
  const compact = normalizeUsernameForModeration(username);
  const compactWithoutNumericAffixes = normalizeUsernameForModeration(
    username.replace(/^\d+|\d+$/g, ''),
  );
  const exactTerms = new Set(prohibitedTerms.exactTerms);
  if (exactTerms.has(compact) || exactTerms.has(compactWithoutNumericAffixes)) {
    return true;
  }

  const tokens = username
    .split('_')
    .flatMap((token) => [
      normalizeUsernameForModeration(token),
      normalizeUsernameForModeration(token.replace(/^\d+|\d+$/g, '')),
    ]);
  return (
    tokens.some((token) => token && exactTerms.has(token)) ||
    prohibitedTerms.substringTerms.some((term) => compact.includes(term))
  );
}

function usernameAllowed(username, prohibitedTerms) {
  return (
    username.length >= 3 &&
    username.length <= 30 &&
    /^[A-Za-z0-9_]+$/.test(username) &&
    !containsProhibitedTerm(username, prohibitedTerms)
  );
}

function generatedUsername(firstName, lastName, userId) {
  const replacements = new Map(
    [...'áàäâãåéèëêíìïîóòöôõúùüûñçýÿ'].map((character, index) => [
      character,
      [...'aaaaaaeeeeiiiiooooouuuuncyy'][index],
    ]),
  );
  const slug = `${firstName ?? ''} ${lastName ?? ''}`
    .toLowerCase()
    .split('')
    .map((character) => replacements.get(character) ?? character)
    .join('')
    .replaceAll(/[^a-z0-9]+/g, '');
  return `${(slug || 'user').slice(0, 13)}_${userId.replaceAll('-', '').slice(0, 16)}`;
}

async function validateProfileIdentityRules(path) {
  const [csv, prohibitedTermsJson] = await Promise.all([
    readFile(path, 'utf8'),
    readFile(USERNAME_PROHIBITED_TERMS, 'utf8'),
  ]);
  const rows = parseCsv(csv);
  const header = rows.shift();
  const columns = new Map(header.map((name, index) => [name, index]));
  for (const name of ['id', 'username', 'first_name', 'last_name', 'gender']) {
    if (!columns.has(name)) {
      throw new Error(`The profiles CSV is missing the ${name} column.`);
    }
  }

  const prohibitedTerms = JSON.parse(prohibitedTermsJson);
  const generated = new Set();
  const identityRules = ['id,generated_username,generation_strategy'];
  let invalidUsernames = 0;
  let missingUsernames = 0;
  let missingGender = 0;

  for (const row of rows) {
    if (row.length !== header.length) {
      throw new Error('The profiles CSV contains an inconsistent row.');
    }
    const username = row[columns.get('username')].trim();
    if (!username) missingUsernames += 1;
    else if (!usernameAllowed(username, prohibitedTerms)) invalidUsernames += 1;

    const gender = row[columns.get('gender')].trim().toLowerCase();
    if (!['male', 'female'].includes(gender)) missingGender += 1;

    let candidate = generatedUsername(
      row[columns.get('first_name')],
      row[columns.get('last_name')],
      row[columns.get('id')],
    );
    let generationStrategy = 'name';
    if (!usernameAllowed(candidate, prohibitedTerms)) {
      candidate = `member_${row[columns.get('id')].replaceAll('-', '').slice(0, 16)}`;
      generationStrategy = 'safe_fallback';
    }
    if (!usernameAllowed(candidate, prohibitedTerms)) {
      throw new Error(`Safe username fallback ${candidate} is not allowed.`);
    }
    if (generated.has(candidate)) {
      throw new Error(`Generated username ${candidate} is not unique.`);
    }
    generated.add(candidate);
    identityRules.push(
      `${row[columns.get('id')]},${candidate},${generationStrategy}`,
    );
  }

  if (
    rows.length !== 533 ||
    invalidUsernames !== 463 ||
    missingUsernames !== 22 ||
    missingGender !== 29
  ) {
    throw new Error(
      'The profiles CSV identity totals do not match the pinned migration contract.',
    );
  }
  return `${identityRules.join('\n')}\n`;
}

function sqlPath(path) {
  return `'${path.replaceAll("'", "''")}'`;
}

function isInsideRepository(path) {
  const pathFromRepository = relative(REPOSITORY_ROOT, path);
  return (
    pathFromRepository === '' ||
    (!pathFromRepository.startsWith('..') && !isAbsolute(pathFromRepository))
  );
}

function runPsql(args, environment) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn('psql', args, {
      env: environment,
      stdio: 'inherit',
    });
    child.once('error', reject);
    child.once('exit', (code, signal) => {
      if (signal) reject(new Error(`psql exited after signal ${signal}.`));
      else if (code !== 0)
        reject(new Error(`psql exited with status ${code}.`));
      else resolvePromise();
    });
  });
}

function postgresEnvironment(databaseUrl) {
  let parsed;
  try {
    parsed = new URL(databaseUrl);
  } catch {
    throw new Error('The database URL is not a valid URL.');
  }
  if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) {
    throw new Error(
      'The database URL must use the postgres or postgresql scheme.',
    );
  }
  if (!parsed.hostname || !parsed.username || parsed.pathname.length < 2) {
    throw new Error(
      'The database URL must include host, user, and database name.',
    );
  }

  const environment = {
    PGHOST: parsed.hostname,
    PGPORT: parsed.port || '5432',
    PGUSER: decodeURIComponent(parsed.username),
    PGDATABASE: decodeURIComponent(parsed.pathname.slice(1)),
  };
  if (parsed.password)
    environment.PGPASSWORD = decodeURIComponent(parsed.password);
  if (parsed.searchParams.has('sslmode')) {
    environment.PGSSLMODE = parsed.searchParams.get('sslmode');
  }
  if (parsed.searchParams.has('connect_timeout')) {
    environment.PGCONNECT_TIMEOUT = parsed.searchParams.get('connect_timeout');
  }
  if (parsed.searchParams.has('options')) {
    environment.PGOPTIONS = parsed.searchParams.get('options');
  }
  return environment;
}

function psqlEnvironment(databaseUrl) {
  const environment = { ...process.env };
  for (const name of [
    'PGHOST',
    'PGPORT',
    'PGUSER',
    'PGPASSWORD',
    'PGDATABASE',
    'PGSSLMODE',
    'PGCONNECT_TIMEOUT',
    'PGOPTIONS',
  ]) {
    delete environment[name];
  }
  return { ...environment, ...postgresEnvironment(databaseUrl) };
}

async function main() {
  const { options, flags } = parseArguments(process.argv.slice(2));
  validateArguments(options, flags);
  if (flags.has('help')) {
    console.log(usage());
    return;
  }

  const apply = flags.has('apply');
  const verifyLocal = flags.has('verify-local');
  if (apply && verifyLocal) {
    throw new Error('--apply and --verify-local are mutually exclusive.');
  }
  const databaseUrl =
    options.get('database-url') ?? process.env.LEGACY_IMPORT_DATABASE_URL;
  if (!databaseUrl) {
    throw new Error(
      'Pass --database-url or set LEGACY_IMPORT_DATABASE_URL. The value is never logged.',
    );
  }
  const connectionEnvironment = psqlEnvironment(databaseUrl);
  if (
    verifyLocal &&
    !['127.0.0.1', 'localhost', '::1'].includes(connectionEnvironment.PGHOST)
  ) {
    throw new Error(
      '--verify-local is restricted to a loopback database host.',
    );
  }

  const inputPaths = new Map();
  for (const [name, expected] of Object.entries(EXPECTED_INPUTS)) {
    const path = options.get(name);
    if (!path || !isAbsolute(path)) {
      throw new Error(`--${name} must be an absolute path.`);
    }
    const actualChecksum = await sha256(path);
    if (actualChecksum !== expected.sha256) {
      throw new Error(
        `${name} checksum mismatch. Expected ${expected.sha256}, received ${actualChecksum}.`,
      );
    }
    inputPaths.set(name, path);
  }
  const profileIdentityRules = await validateProfileIdentityRules(
    inputPaths.get('profiles'),
  );

  let backupDirectory;
  if (apply) {
    if (options.get('confirm') !== CONFIRMATION) {
      throw new Error(`Apply requires --confirm=${CONFIRMATION}.`);
    }
    if (!flags.has('backup-confirmed')) {
      throw new Error(
        'Apply requires --backup-confirmed after verifying a recoverable database backup.',
      );
    }
    const backupRoot = options.get('backup-dir');
    if (!backupRoot || !isAbsolute(backupRoot)) {
      throw new Error('Apply requires an absolute --backup-dir path.');
    }
    if (isInsideRepository(resolve(backupRoot))) {
      throw new Error('The backup directory must be outside the repository.');
    }
    const timestamp = new Date().toISOString().replaceAll(/[:.]/g, '-');
    backupDirectory = resolve(backupRoot, `legacy-user-import-${timestamp}`);
    await mkdir(backupDirectory, { recursive: false });
  }

  const temporaryDirectory = await mkdtemp(
    join(tmpdir(), 'doit4jesus-legacy-import-'),
  );
  const materializedSqlPath = join(temporaryDirectory, 'import.sql');
  const profileIdentityRulesPath = join(
    temporaryDirectory,
    'profile-identity-rules.csv',
  );

  try {
    await writeFile(profileIdentityRulesPath, profileIdentityRules, {
      mode: 0o600,
    });
    let sql = await readFile(SQL_TEMPLATE, 'utf8');
    for (const [name, expected] of Object.entries(EXPECTED_INPUTS)) {
      sql = sql.replaceAll(expected.token, sqlPath(inputPaths.get(name)));
    }
    sql = sql.replaceAll(
      '__PROFILE_IDENTITIES_CSV__',
      sqlPath(profileIdentityRulesPath),
    );
    await writeFile(materializedSqlPath, sql, { mode: 0o600 });

    const backupNames = [
      'app_users',
      'user_profiles',
      'spiritual_activities',
      'point_ledger',
      'user_progress',
      'user_badges',
      'user_badge_progress',
      'user_badge_requirement_progress',
      'badge_shares',
      'challenge_progress_events',
      'leaderboard_periods',
      'leaderboard_entries',
    ];
    const psqlVariables = backupNames.flatMap((name) => [
      '-v',
      `${name}_backup=${
        apply ? join(backupDirectory, `${name}.csv`) : '/dev/null'
      }`,
    ]);

    console.log(
      apply
        ? `Applying replacement import. Affected-row exports: ${backupDirectory}`
        : verifyLocal
          ? 'Verifying the full replacement transaction locally. All changes will be rolled back.'
          : 'Previewing replacement import. No persistent rows will be changed.',
    );

    await runPsql(
      [
        '-X',
        '-v',
        'ON_ERROR_STOP=1',
        '-v',
        `mutate=${apply || verifyLocal ? 'true' : 'false'}`,
        '-v',
        `commit=${apply ? 'true' : 'false'}`,
        '-v',
        `verify=${verifyLocal ? 'true' : 'false'}`,
        ...psqlVariables,
        '-f',
        materializedSqlPath,
      ],
      {
        ...process.env,
        ...connectionEnvironment,
      },
    );
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
