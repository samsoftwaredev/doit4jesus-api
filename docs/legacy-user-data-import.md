# Legacy user data import

The legacy importer restores the pinned profile, Rosary, and XP exports without
checking personal data into this repository. It matches records exclusively by
an existing `auth.users.id`; an exported profile without a matching Auth user is
reported and skipped.

## Preview

Apply all repository migrations first, then run the command with absolute CSV
paths and a direct PostgreSQL connection string. Prefer the environment variable
so the credential is not stored in shell history.

```sh
export LEGACY_IMPORT_DATABASE_URL='postgresql://...'
npm run import:legacy-user-data -- \
  --profiles=/absolute/path/profiles_rows.csv \
  --rosary-stats=/absolute/path/rosary_stats_rows.csv \
  --user-xp=/absolute/path/user_xp_rows.csv
```

Preview mode is the default. It verifies the pinned SHA-256 checksums, loads the
CSVs into temporary typed tables, validates their internal relationships, and
prints every matched account with the current and replacement totals. The
transaction is rolled back and no application rows are changed.

For a full local integration check, add `--verify-local`. This temporarily maps
one high-activity export user to an existing local Auth account, runs the entire
replacement path and every postcondition, then rolls the transaction back. The
flag refuses non-loopback database hosts.

## Apply

Before applying to a hosted database:

1. Verify that a recoverable platform backup or point-in-time recovery point
   exists.
2. Review the preview's matched-account report.
3. Choose an absolute backup directory outside this repository.
4. Use a brief maintenance window because the transaction takes write locks on
   the affected profile, competition, badge, and leaderboard tables.

```sh
npm run import:legacy-user-data -- \
  --profiles=/absolute/path/profiles_rows.csv \
  --rosary-stats=/absolute/path/rosary_stats_rows.csv \
  --user-xp=/absolute/path/user_xp_rows.csv \
  --apply \
  --confirm=REPLACE_MATCHED_LEGACY_DATA \
  --backup-confirmed \
  --backup-dir=/absolute/path/outside/repository
```

Apply mode creates a timestamped directory containing CSV exports of every
affected table before it changes rows. All database changes then run in one
transaction. A failed validation, lock timeout, SQL error, or postcondition
rolls the transaction back; the client-side backup exports remain available.

## Mapping and replacement rules

- Existing nonblank profile values win. A blank username uses the valid legacy
  username when it is available. Invalid, missing, or conflicting legacy
  usernames are replaced with a deterministic value made from the person's
  normalized first and last name plus 16 characters of the user UUID (for
  example, `mariajose_12ab34cd56ef7890`). The UUID suffix makes reruns stable
  and prevents two people with the same name from colliding. Every proposal is
  checked against the application's prohibited-term rules; if the name-derived
  value is rejected, the importer uses the deterministic safe form
  `member_<UUID>` and reports that fallback.
- Known `male` or `female` legacy gender values fill blank gender fields. The
  importer does not guess gender from a name: a missing or unrecognized value
  stays null, keeps onboarding incomplete, and is reported as
  `confirmation_required` for the user to answer.
- Valid legacy names, avatar URLs, titles, language, and the `US` country
  mapping fill the remaining blank profile fields.
- City, birth date, role, last-seen, stored Rosary totals/streaks, and legacy
  level numbers are not imported.
- All current Rosary activities and point-ledger rows for matched accounts are
  replaced, including records newer than the export.
- Imported Rosaries are self-reported `import` activities. Their legacy UUID,
  completion date, optional joined-user UUID, and creation timestamp remain in
  metadata.
- The XP export becomes one `legacy_balance` adjustment per nonzero balance.
  New level thresholds determine `current_level`; weekly and yearly points
  restart at zero.
- Legacy balance adjustments are excluded from period leaderboard points,
  while imported Rosaries continue to count in activity totals.
- The canonical `FIRST_ROSARY` badge and its progress are rebuilt exactly.
  Qualifying existing awards keep their row identity, preserving badge shares;
  unqualified awards are removed.

The importer intentionally refuses to run if the Rosary badge rules or
leaderboard function no longer have the expected shape. Review and update the
import logic instead of bypassing those guards.
