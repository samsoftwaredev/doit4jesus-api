---
name: api-endpoint-workflow
description: Add, change, or review HTTP endpoints in this repository while keeping route behavior, validation, authentication, tests, OpenAPI, Postman, and compatibility synchronized. Use when a request changes the public API contract; do not use for database-only work or diagnosis that does not change a contract.
---

# API Endpoint Workflow

Implement the requested endpoint behavior end to end without widening the task or silently breaking existing clients.

## Establish the contract

1. Read the active `AGENTS.md` instructions and the closest analogous route under `src/app/api/v1/`.
2. Locate the route's Zod schemas, authentication helper, database query or RPC, focused tests, OpenAPI operation, Postman request, and any prose documentation. Use `rg` to find consumers before changing names or shapes.
3. State or infer the method, path, authentication level, request fields, normalization, response envelope, status codes, pagination, caching, and idempotency requirements. Ask only when a missing decision would materially change the contract.
4. Preserve backward compatibility unless the user explicitly requests a breaking change. Treat changing required fields, nullability, defaults, status codes, or response keys as contract changes.

## Implement consistently

- Put route handlers in `src/app/api/v1/**/route.ts` and follow the closest route's structure.
- Use `requireUser` for authenticated endpoints and `requireAdmin` for administrator endpoints. Make a route public only when the contract explicitly requires it.
- Parse JSON through `readJson`, then a strict Zod object schema. Validate query and path inputs through shared or feature schemas when available.
- Keep external JSON in camelCase and map explicitly to snake_case database arguments and columns.
- Use `throwDatabaseError` for Supabase/PostgREST failures. Add a precise mapping in `src/lib/api/database.ts` when a new database error has stable client semantics.
- Return responses through `ok`, `created`, or `noContent`, and route caught failures through `errorResponse(error, request)`.
- For multi-table, reward-bearing, or otherwise atomic writes, prefer an existing or purpose-built database RPC. Preserve existing idempotency behavior and require an idempotency key for reward-bearing writes.
- Match the neighboring endpoint's pagination style. Bound page sizes and return pagination metadata through the established response envelope.
- Add `Cache-Control: no-store` when returning user-specific state that must not be cached.

## Synchronize the public surface

When behavior changes, update every applicable artifact in the same task:

- Zod schemas in `src/lib/schemas/`.
- Focused Jest tests in `__test__/`.
- The path, parameters, bodies, responses, examples, and reusable components in `public/openapi.yaml`.
- The matching request, variables, example body, and description in `postman/holy-competition.postman_collection.json`.
- `README.md` or feature documentation under `docs/` when public usage or setup changes.
- Supabase types and migrations only when the database contract also changes; use `$supabase-migration-workflow` for that portion.

Keep OpenAPI requiredness, nullability, enums, bounds, defaults, and examples aligned with runtime validation. Keep Postman examples executable and free of real credentials or personal data.

## Verify

Cover the success path and relevant contract boundaries: authentication, malformed JSON, invalid or omitted inputs, normalization, pagination, database error mapping, idempotent replay, and response shape. Avoid assertions that merely duplicate implementation details.

Run the smallest focused Jest command first, then `pnpm typecheck`, `pnpm lint:check`, and `pnpm format:check` for changed code. Run `pnpm verify:push` when the change is broad or before final handoff if practical. Report exactly which checks ran and any checks that remain.

## Handoff

Summarize the resulting contract, compatibility impact, synchronized artifacts, and verification results. Call out any client migration or unapplied database migration explicitly.
