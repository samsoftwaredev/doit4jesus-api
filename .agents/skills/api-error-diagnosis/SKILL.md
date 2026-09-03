---
name: api-error-diagnosis
description: Diagnose 4xx or 5xx failures from this repository's Next.js API using the request method, URL, payload, response body, request ID, route code, validation, authentication, and Supabase behavior. Use when asked why an endpoint failed; implement a fix only when the user also asks for one.
---

# API Error Diagnosis

Find the first failing boundary, support the conclusion with evidence, and preserve the distinction between diagnosis and authorization to modify code or data.

## Capture the symptom

Collect what is available without blocking on every missing item:

- HTTP method and complete route path.
- Status code and structured response body.
- Request payload, query parameters, and relevant headers.
- `x-request-id`, timestamp, and whether the caller used cookie or Bearer authentication.
- Whether the failure reproduces locally, in tests, or only in a deployed environment.

Never print access tokens, cookies, service-role keys, passwords, or unnecessary personal data. Redact them in commands and reports.

## Trace the request in order

1. Locate the exact `src/app/api/v1/**/route.ts` handler and its focused tests.
2. Check middleware and `requireUser` or `requireAdmin` behavior, including Bearer-versus-cookie authentication.
3. Check `readJson`, query/path parsing, and the invoked Zod schema. Compare the actual payload with strict requiredness, nullability, transforms, enums, and unknown-key behavior.
4. Follow normalization and mapping from external camelCase fields to database columns or RPC arguments.
5. Follow the exact Supabase query or RPC into the latest effective migration definition. Confirm that the migration is applied to the database being queried.
6. Trace failures through `throwDatabaseError` and `errorResponse` to determine why the observed status, code, and public message were returned.
7. Reproduce at the narrowest useful layer: a focused route test first when possible, then a local HTTP request or read-only database query when runtime state matters.

Do not assume the payload is at fault merely because the response is a 4xx. Verify the validation and database state that produced it.

## Interpret this repository's errors

- `400 BAD_REQUEST` usually indicates invalid JSON, content type, or malformed pagination/input parsing outside Zod.
- `401 UNAUTHORIZED` comes from missing or invalid authentication.
- `403 FORBIDDEN`, `404 NOT_FOUND`, and `409 CONFLICT` represent mapped authorization, absence, or state/uniqueness errors.
- `422 VALIDATION_ERROR` may come from Zod, PostgreSQL `23503` or `22023`, or a deliberately mapped `P0001` RPC message such as `PROFILE_COUNTRY_NOT_FOUND`.
- `500 DATABASE_ERROR` means `throwDatabaseError` received an unmapped database error and replaced it with a safe fallback message.
- `500 INTERNAL_ERROR` means `errorResponse` received an error that was neither `ApiError` nor `ZodError`.

The response request ID comes from the incoming `x-request-id` header or a generated UUID. Search logs for it, but verify the logging path: current database fallback logging does not automatically include the request ID. If no component propagates the ID into the relevant log, report that observability gap instead of claiming a correlation.

## Diagnose database-backed failures

- Compare the RPC signature in the route with the effective database signature and generated TypeScript types.
- Check migration history before concluding that repository SQL matches the running database.
- Use read-only queries to verify referenced rows, constraints, grants, policies, function ownership, and the authenticated role's visibility.
- Treat RLS, grants, and `security definer` settings as separate authorization layers.
- Preserve the original database code, message, details, and hint in private diagnostics, but do not expose sensitive internals in the client response.

## Regression coverage and fix boundary

For diagnosis-only requests, explain the root cause and propose the narrowest regression test and fix; do not modify files or data. When the user asks for a fix, add a test that fails for the demonstrated cause, implement the smallest complete correction, and run the focused test plus relevant type, lint, and format checks. Use `$api-endpoint-workflow` when the fix changes the public contract and `$supabase-migration-workflow` when it changes the database.

Report the failing layer, evidence, why it maps to the observed response, fix status, verification performed, and any remaining environment mismatch.
