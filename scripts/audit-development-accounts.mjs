#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const AUDIT_SQL = resolve(SCRIPT_DIRECTORY, 'audit-development-accounts.sql');

function usage() {
  return `Usage:
  npm run db:audit:development-accounts -- \\
    --database-url=postgresql://...

The URL may instead be supplied through PRODUCTION_DATABASE_URL. This command
is read-only. It exits unsuccessfully if a known local fixture UUID or email is
present, and never deletes or changes an account.`;
}

function databaseUrlFromArguments(values) {
  let databaseUrl = process.env.PRODUCTION_DATABASE_URL;
  let argumentSeen = false;

  for (const value of values) {
    if (value === '--help') {
      console.log(usage());
      process.exit(0);
    }
    if (!value.startsWith('--database-url=')) {
      throw new Error(`Unknown argument: ${value}`);
    }
    if (argumentSeen) {
      throw new Error('--database-url may be supplied only once.');
    }
    argumentSeen = true;
    databaseUrl = value.slice('--database-url='.length);
  }

  if (!databaseUrl) throw new Error(usage());
  return databaseUrl;
}

function postgresEnvironment(value) {
  const databaseUrl = new URL(value);
  if (!['postgres:', 'postgresql:'].includes(databaseUrl.protocol)) {
    throw new Error(
      'The database URL must use the postgres:// or postgresql:// scheme.',
    );
  }

  const environment = {
    ...process.env,
    PGHOST: databaseUrl.hostname,
    PGPORT: databaseUrl.port || '5432',
    PGUSER: decodeURIComponent(databaseUrl.username),
    PGPASSWORD: decodeURIComponent(databaseUrl.password),
    PGDATABASE: decodeURIComponent(databaseUrl.pathname.replace(/^\//, '')),
  };
  const sslMode = databaseUrl.searchParams.get('sslmode');
  if (sslMode) environment.PGSSLMODE = sslMode;
  return environment;
}

async function main() {
  const databaseUrl = databaseUrlFromArguments(process.argv.slice(2));
  const child = spawn(
    'psql',
    ['-X', '-v', 'ON_ERROR_STOP=1', '-f', AUDIT_SQL],
    {
      env: postgresEnvironment(databaseUrl),
      stdio: 'inherit',
    },
  );

  child.on('error', (error) => {
    console.error(`Unable to run psql: ${error.message}`);
    process.exitCode = 1;
  });
  child.on('exit', (code, signal) => {
    if (signal) {
      console.error(`Development-account audit stopped by ${signal}.`);
      process.exitCode = 1;
      return;
    }
    process.exitCode = code ?? 1;
  });
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
