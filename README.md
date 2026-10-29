# DoIt4Jesus API

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

For a clean local catalog-only database, apply every migration and the safe
default seed path:

```bash
supabase db reset --local
```

The default seed contains no Auth users, credentials, churches, or operational
examples. To opt into the four known-password development accounts and their
dependent sample workflows, use the explicitly local command instead:

```bash
npm run db:reset:local-fixtures
```

That command destroys and recreates only the local Supabase database. Never run
`supabase/seed/local-fixtures.sql` against a hosted database.

For a linked hosted project, deploy catalog data through migrations only. Do not
use `--include-seed`:

```bash
supabase db push --linked --dry-run
npm run db:audit:development-accounts -- --database-url=postgresql://...
supabase db push --linked
```

The production sequence is: review the dry run, run the read-only fixture-account
audit, stop if it finds any known development UUID or email, confirm a recoverable
backup, obtain explicit production approval, and only then run the final push.
The audit and catalog migration never delete accounts. Any hosted deletion needs
a separate backup-first plan and approval.

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

Level and badge images are read from the public Supabase Storage bucket named
`images` by default. Set `SUPABASE_PUBLIC_IMAGE_BUCKET` if the bucket uses a
different name.

`SUPABASE_SERVICE_ROLE_KEY` is server-only and is not used by the public API routes. Keep it only for trusted workers or administrative jobs.

### 3a. Configure the Resend Email Center

The admin Email Center requires a Resend API key, a Resend-verified sender,
reply address, physical mailing address, existing Segment ID, webhook signing
secret, and the deployed app URL:

```text
RESEND_API_KEY
RESEND_FROM_EMAIL
RESEND_REPLY_TO
RESEND_PHYSICAL_ADDRESS
RESEND_SEGMENT_ID
RESEND_WEBHOOK_SECRET
APP_URL
```

Configure Resend to deliver `email.sent`, `email.delivered`,
`email.bounced`, `email.complained`, `email.opened`, `email.clicked`,
`email.suppressed`, and `contact.updated` events to:

```text
https://YOUR_DOMAIN/api/v1/webhooks/resend
```

Campaigns use Resend Broadcasts and the configured Segment. The app only
launches a draft after it has passed a send to every saved test-recipient
address. The active-user audience is used only where the operator has
documented existing marketing consent.

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

### 6. Enable Google sign-in

Create a **Web application** OAuth client in [Google Cloud](https://console.cloud.google.com/auth/clients). Add the app's origins (for example, `http://localhost:3000` and `https://YOUR_DOMAIN`) and this Supabase callback URI:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

In **Supabase Dashboard → Authentication → Sign In / Providers → Google**, enable Google and enter the client ID and secret. Keep the local development values in `.env.local`:

```text
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID="..."
SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_SECRET="..."
```

For local Supabase, add `http://127.0.0.1:54321/auth/v1/callback` to the Google OAuth client's authorized redirect URIs, then restart Supabase after setting those environment variables.

## Authentication

Browser clients can use Supabase Auth normally; `@supabase/ssr` stores and refreshes the session in cookies.

Native or external clients can send:

```http
Authorization: Bearer <SUPABASE_ACCESS_TOKEN>
```

Never send the service-role key to a browser or native application.

## API surface

| Method           | Route                                        | Purpose                                                 |
| ---------------- | -------------------------------------------- | ------------------------------------------------------- |
| GET              | `/api/v1/health`                             | Health check                                            |
| GET/PATCH/DELETE | `/api/v1/me`                                 | Current profile; DELETE permanently removes the account |
| POST             | `/api/v1/me/daily-scripture/completions`     | Persist a completion; validates the date against USCCB  |
| DELETE           | `/api/v1/admin/users/:userId`                | Administrator-only permanent account deletion           |
| GET              | `/api/v1/screen-data`                        | Initial data for one Home, Prayer, or Community screen  |
| GET/PATCH        | `/api/v1/me/notification-preferences`        | Onboarding reminder preferences                         |
| POST             | `/api/v1/me/onboarding/complete`             | Transactional profile setup; reminders default off      |
| GET              | `/api/v1/usernames/random`                   | Five valid, currently available username suggestions    |
| GET              | `/api/v1/usernames/validate`                 | Username rules, availability, and suggestions           |
| GET              | `/api/v1/progress`                           | XP and current/next level                               |
| GET              | `/api/v1/levels`                             | Level definitions                                       |
| GET              | `/api/v1/locations/countries`                | Country list and autocomplete                           |
| GET              | `/api/v1/examination-of-conscience`          | Public question list or random selection                |
| GET              | `/api/v1/examination-of-conscience/daily`    | Deterministic public daily question                     |
| GET/POST         | `/api/v1/activities`                         | Activity history and transactional recording            |
| GET              | `/api/v1/challenges`                         | Challenge assignments                                   |
| POST             | `/api/v1/challenges/:assignmentId/claim`     | Claim completed challenge reward                        |
| GET              | `/api/v1/badges`                             | Badge catalog, earned badges, and progress              |
| GET              | `/api/v1/leaderboards`                       | Global Rosary and country points leaderboards           |
| GET              | `/api/v1/prayer-map`                         | Aggregated privacy-filtered markers                     |
| GET              | `/api/v1/notifications`                      | Notification inbox                                      |
| PATCH            | `/api/v1/notifications/:notificationId/read` | Mark notification read                                  |

Global Rosary leaderboards support weekly and lifetime periods. Lifetime totals
include every self-reported or verified Rosary activity through the latest
refresh, including individually imported legacy Rosaries; users with no
qualifying Rosaries are omitted. Country and friends leaderboards retain weekly
and yearly point periods. PostgreSQL refreshes the projections every five
minutes, and an explicit `periodCode` can retrieve a historical weekly period.

## Record an activity

Every POST requires an idempotency key. Retrying the same request with the same key returns the original activity instead of awarding points twice.

Use `GET /api/v1/activities?include=points` to add each returned activity's signed net point total, including reversals and adjustments.

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
- Prayer-map projection jobs.
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

# Apple credential revocation

Permanent deletion of an account linked to Apple calls the Apple token-revocation endpoint before deleting local data. Configure `APPLE_CLIENT_ID` with the iOS Services/App ID and `APPLE_CLIENT_SECRET` with a current Apple client-secret JWT. Rotate the secret before it expires and verify revocation on a physical iPhone before App Review.
