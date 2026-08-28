# Holy Competition API

Production-oriented API scaffold for the supplied PostgreSQL/Supabase schema, implemented with Next.js 16 App Router Route Handlers and deployable to Vercel.

## What is included

- Supabase Auth with browser cookies and Bearer JWT support.
- Next.js 16 `proxy.ts` session refresh.
- User-scoped Supabase clients so PostgreSQL RLS remains authoritative.
- Zod request validation and consistent JSON error responses.
- Idempotent activity recording.
- Transactional XP, level, challenge-progress, prayer-event, notification, and outbox updates.
- REST endpoints for profiles, progression, activities, challenges, badges, leaderboards, prayer maps, and notifications.
- SQL migrations that connect `app.users` to `auth.users` and add RLS policies.
- OpenAPI contract at `/openapi.yaml`.

## Critical schema correction

Supabase Auth must own passwords and authentication credentials. `app.users.id` is changed to reference `auth.users.id`; `password_hash` is removed. All domain tables can continue referencing `app.users`, preserving the original model while sharing the Auth UUID.

The first migration refuses to continue when legacy `app.users` IDs do not exist in `auth.users`. Do not bypass this check. Migrate or remap those users first.

## Setup

### 1. Create and seed the Supabase database

Apply the supplied baseline schema first, including level definitions and activity/point-rule seeds. Then apply:

```bash
supabase db push
```

The migrations in this repository assume the baseline tables already exist.

Load the complete country/city catalog after the location migration is
applied:

```bash
pnpm import:locations
```

The administrative importer reads `NEXT_PUBLIC_SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` from `.env.local`, downloads a pinned upstream
release, verifies its SHA-256 checksum, and upserts the catalog in batches. Run
`pnpm import:locations -- --dry-run` to download and validate without changing
the database. See [location data and licensing](docs/location-data.md) for the
source attribution and ODbL obligations.

### 2. Expose only the required schemas

In Supabase **Project Settings → API → Exposed schemas**, add:

```text
app, competition, prayer, api
```

Do **not** expose `platform`. It contains idempotency and outbox internals.

### 3. Configure environment variables

Copy `.env.example` to `.env.local`:

```bash
cp .env.example .env.local
```

Required for public/user requests:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
```

`SUPABASE_SERVICE_ROLE_KEY` is server-only and is not used by the public API routes. Keep it only for trusted workers or administrative jobs.

### 4. Install and run

```bash
npm install
npm run typecheck
npm run dev
```

Health endpoint:

```text
GET http://localhost:3000/api/v1/health
```

### 5. Configure Auth redirects

Add the local and deployed callback URLs in Supabase Auth settings:

```text
http://localhost:3000/auth/callback
https://YOUR_DOMAIN/auth/callback
```

## Authentication

Browser clients can use Supabase Auth normally; `@supabase/ssr` stores and refreshes the session in cookies.

Native or external clients can send:

```http
Authorization: Bearer <SUPABASE_ACCESS_TOKEN>
```

Never send the service-role key to a browser or native application.

## API surface

| Method    | Route                                        | Purpose                                       |
| --------- | -------------------------------------------- | --------------------------------------------- |
| GET       | `/api/v1/health`                             | Health check                                  |
| GET/PATCH | `/api/v1/me`                                 | Current profile                               |
| GET       | `/api/v1/usernames/validate`                 | Username rules, availability, and suggestions |
| GET       | `/api/v1/progress`                           | XP and current/next level                     |
| GET       | `/api/v1/levels`                             | Level definitions                             |
| GET       | `/api/v1/locations/countries`                | Country list and autocomplete                 |
| GET       | `/api/v1/locations/cities`                   | Country-scoped city autocomplete              |
| GET/POST  | `/api/v1/activities`                         | Activity history and transactional recording  |
| GET       | `/api/v1/challenges`                         | Challenge assignments                         |
| POST      | `/api/v1/challenges/:assignmentId/claim`     | Claim completed challenge reward              |
| GET       | `/api/v1/badges`                             | Badge catalog, earned badges, and progress    |
| GET       | `/api/v1/leaderboards`                       | Period/scope leaderboard                      |
| GET       | `/api/v1/prayer-map`                         | Aggregated privacy-filtered markers           |
| GET       | `/api/v1/notifications`                      | Notification inbox                            |
| PATCH     | `/api/v1/notifications/:notificationId/read` | Mark notification read                        |

## Record an activity

Every POST requires an idempotency key. Retrying the same request with the same key returns the original activity instead of awarding points twice.

```bash
curl -X POST 'http://localhost:3000/api/v1/activities' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: 01J-ROSARY-2026-07-18-USER-REQUEST' \
  -d '{
    "activityCode": "ROSARY",
    "occurredAt": "2026-07-18T13:00:00Z",
    "completedAt": "2026-07-18T13:22:00Z",
    "durationSeconds": 1320,
    "quantity": 1,
    "countryCode": "US"
  }'
```

The database function atomically:

1. Inserts the spiritual activity.
2. Applies active point rules and daily/weekly limits.
3. Writes the append-only point ledger.
4. Updates cached user progression and level.
5. Advances matching active challenges.
6. Creates a prayer event when applicable.
7. Creates notifications and outbox events.

## Deploy to Vercel

1. Import the repository into Vercel.
2. Add the same environment variables.
3. Use the Node.js runtime default for Route Handlers.
4. Add the deployed `/auth/callback` URL to Supabase Auth.
5. Deploy and call `/api/v1/health`.

## Production work still needed

This scaffold is the correct API foundation, not the entire game backend. Before a broad launch, add:

- Vercel/Supabase-compatible rate limiting.
- Automated tests against a local Supabase instance.
- Challenge assignment and expiration jobs.
- Outbox processing with retry/dead-letter behavior.
- Leaderboard and prayer-map projection jobs.
- Rebuild/reset logic for cached weekly and yearly counters.
- Abuse controls for self-reported activities and high-value rewards.
- Moderation and privacy rules for usernames, avatars, and shared badges.

## Type generation

`src/lib/supabase/types.ts` contains the minimum types needed by this scaffold. Replace it with types generated from your actual Supabase project after applying all migrations so schema drift fails during CI.

## Pipeline development

1. unit test
2. end to end test
3. ts validation
4. npm run build
5. versioning
6. publishing

## Catholic Resources

https://github.com/servusdei2018/awesome-catholic
