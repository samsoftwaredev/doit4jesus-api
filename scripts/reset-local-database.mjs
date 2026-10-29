import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));
const seedPaths = [
  './seed.sql',
  './seed/local-fixtures.sql',
  './seed/verify.sql',
  './seed/verify-local-fixtures.sql',
];

console.log(
  'Resetting the local Supabase database and loading local fixtures...',
);

const result = spawnSync(
  'supabase',
  [
    'db',
    'reset',
    '--local',
    ...seedPaths.flatMap((seedPath) => ['--sql-paths', seedPath]),
  ],
  {
    cwd: projectRoot,
    stdio: 'inherit',
  },
);

if (result.error) {
  if (result.error.code === 'ENOENT') {
    console.error(
      'Supabase CLI was not found. Install it and ensure `supabase` is available on PATH.',
    );
  } else {
    console.error(
      `Unable to reset the local database: ${result.error.message}`,
    );
  }

  process.exitCode = 1;
} else {
  process.exitCode = result.status ?? 1;
}
