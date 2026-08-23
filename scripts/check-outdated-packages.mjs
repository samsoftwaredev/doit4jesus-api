#!/usr/bin/env node

/**
 * Lists direct dependencies with newer registry versions.
 *
 * By default this is advisory so a commit can proceed. Pass --strict from the
 * pre-push verification to reject both outdated packages and failed checks.
 */
import { spawnSync } from 'node:child_process';

const strict = process.argv.includes('--strict');
const result = spawnSync(
  'pnpm',
  ['outdated', '--format', 'json', '--no-color'],
  {
    encoding: 'utf8',
    shell: process.platform === 'win32',
    timeout: 15_000,
  },
);

function failOrWarn(message) {
  const output = strict ? console.error : console.warn;
  output(message);
  if (strict) process.exitCode = 1;
}

if (result.error) {
  failOrWarn(`Unable to check outdated packages: ${result.error.message}.`);
} else {
  let packages;
  try {
    const parsed = result.stdout.trim() ? JSON.parse(result.stdout) : [];
    packages = Array.isArray(parsed)
      ? parsed
      : Object.entries(parsed).map(([name, dependency]) => ({
          name,
          ...dependency,
        }));
  } catch {
    failOrWarn(
      `Unable to read pnpm outdated output: ${result.stderr.trim() || 'unknown error'}.`,
    );
  }

  if (Array.isArray(packages)) {
    if (packages.length === 0) {
      console.log('✓ All direct packages are current.');
    } else {
      failOrWarn(`Outdated packages (${packages.length}):`);
      for (const dependency of packages.sort((left, right) =>
        left.name.localeCompare(right.name),
      )) {
        console.log(
          `  - ${dependency.name}: ${dependency.current} → ${dependency.latest}`,
        );
      }
    }
  }
}
