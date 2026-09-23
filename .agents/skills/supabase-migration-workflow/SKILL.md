---
name: supabase-migration-workflow
description: Create, review, apply, or diagnose Supabase/PostgreSQL migrations in this repository, including tables, functions, RPCs, grants, RLS policies, reference data, seed verification, and TypeScript database types. Use for database contract changes; do not use for application-only query edits.
---

# Supabase Migration Workflow

Evolve the database with a forward-only, reviewable migration and keep every affected consumer synchronized.

## Inspect before changing

1. Read the active `AGENTS.md` instructions.
2. Search all migrations for the affected object. For functions and policies, identify the latest effective definition rather than assuming the first match is current.
3. Inspect application callers, `src/lib/supabase/types.ts`, `supabase/seed.sql`, files under `supabase/seed/`, tests, OpenAPI, and documentation that depend on the database contract.
4. Check local Supabase status before relying on a local database. Distinguish repository state, local database state, and hosted database state; do not assume they are synchronized.
5. Identify data-preservation, locking, rollback, authorization, and client-compatibility risks before writing SQL.

## Design the migration

- Add a uniquely named, chronologically ordered file under `supabase/migrations/`. Never rewrite an existing migration that may have been applied.
- Make the migration safe across the actual supported starting state. Use guards when they preserve correctness, but do not hide an unexpected missing prerequisite.
- For required columns, prefer an explicit add/backfill/validate/enforce sequence when existing rows may be present.
- Preserve data and dependent objects unless removal was explicitly requested.
- Schema-qualify objects and references.
- For tables, consider constraints, indexes, ownership, RLS enablement, policies, and explicit grants together.
- For `security definer` functions, set an empty or tightly controlled `search_path`, schema-qualify referenced objects, revoke unintended execution from `public`, `anon`, and `authenticated`, then grant only the intended roles.
- Keep API-facing RPC argument names, return shapes, error messages, volatility, and permissions compatible unless a breaking change is explicit.
- Use stable PostgreSQL error codes and messages that `src/lib/api/database.ts` can map deliberately. Do not leak internal SQL details to clients.
- Write reference-data inserts and seed changes so reruns do not create duplicates or overwrite curated values unintentionally.

## Destructive-operation gate

Writing a forward migration that contains an explicitly requested removal is allowed. Before executing any `DROP`, `TRUNCATE`, broad `DELETE` or `UPDATE`, database reset, irreversible data rewrite, or destructive migration against a local or hosted database:

1. Resolve the exact database and affected objects with read-only checks.
2. Explain the impact and recovery path.
3. Obtain explicit current-task permission immediately before execution.

Never execute a migration against a hosted project unless the user explicitly requests that environment. Prefer a disposable or local database for validation.

## Synchronize consumers

- Update affected entries in `src/lib/supabase/types.ts` with a focused edit unless the user requests and approves a full regeneration workflow.
- Update `supabase/seed.sql` and the relevant files in `supabase/seed/` when a clean database needs the new data or shape.
- Extend `supabase/seed/verify.sql` when the new invariant should be checked after every seed.
- Update routes, schemas, database error mappings, tests, OpenAPI, Postman, and documentation when the database change affects them. Use `$api-endpoint-workflow` for public endpoint contract work.

## Verify proportionally

- Inspect `supabase db push --help` or the relevant CLI help before relying on version-sensitive flags.
- Validate SQL against a local database when available. Use fail-fast execution and a transaction when the operation supports it.
- For destructive SQL, satisfy the destructive-operation gate even on a local database with valuable state.
- Run seed verification when seed data changes.
- Run relevant Jest tests and `npm run typecheck`; add lint and formatting checks when TypeScript or documentation changed.
- Query the resulting catalogs, function signatures, policies, grants, constraints, indexes, and representative data rather than treating a zero exit code as complete verification.

Report the migration filename, affected objects and rows, execution environment, synchronization work, commands run, and any unapplied or unverified state.
