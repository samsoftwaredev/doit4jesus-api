# AGENTS.md

## Project

This is a Next.js TypeScript application backed by Supabase/PostgreSQL.

- Package manager: npm 11.19.0.
- Node.js: 24 or newer.
- Tests: Jest.
- API routes: `src/app/api/v1/`.
- Validation schemas: `src/lib/schemas/`.
- Database migrations: `supabase/migrations/`.
- Seed data: `supabase/seed.sql`.
- Database types: `src/lib/supabase/types.ts`.
- OpenAPI specification: `public/openapi.yaml`.

## Development commands

- Install dependencies: `npm install` (or `npm ci` for a clean lockfile install).
- Start the development server: `npm run dev`.
- Type-check: `npm run typecheck`.
- Check linting: `npm run lint:check`.
- Check formatting: `npm run format:check`.
- Run tests: `npm test`.
- Run full pre-push verification: `npm run verify:push`.

## API changes

When changing an endpoint:

- Validate request data through the existing schema layer.
- Preserve the established authentication, success-response, and error-response conventions.
- Add or update focused route tests.
- Update `public/openapi.yaml` when the public contract changes.
- Update relevant documentation and Postman examples when applicable.
- Do not expose internal database errors to clients.

## Database changes

- Create a new forward-only migration for every schema or reference-data change.
- Never edit a migration that may already have been applied.
- Make migrations idempotent when practical.
- Keep `src/lib/supabase/types.ts` synchronized with the database schema.
- Update `supabase/seed.sql` when required for a clean local environment.
- Do not reset, delete, or rewrite database data unless the user explicitly requests it.

## Domain rules

- User profiles and onboarding use `countryCode`.
- Profiles must not store or return `cityId`, `city`, or equivalent city fields.
- City information is allowed only for church-related records and endpoints.
- Valid profile country codes must exist in the countries reference table.
- The countries reference table must contain the complete supported ISO country list.

## Working-tree safety

- Preserve unrelated user changes in the working tree.
- Do not run destructive Git commands.
- Do not overwrite or remove unrecognized files.
- Never commit credentials, access tokens, local environment files, or other secrets.

## Definition of done

Before completing a change:

- Relevant tests pass.
- Type-checking passes.
- Linting and formatting checks pass.
- Database migrations, database types, seed data, API documentation, and tests are synchronized when applicable.
