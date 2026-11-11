# Church discovery and reminder subscriptions

The Visit Jesus in the Tabernacle backend provides authenticated U.S. postal-code discovery, nearby church search, per-church notification preferences, administrator schedule verification, and dated upcoming-service occurrences.

## Directory import

Apply the database migration before importing. The importer is pinned to the checked-in `churches_all_candidates.csv` and `zip_city_diocese_timezone.csv` hashes and validates the expected source counts.

With no database URL, the importer targets the local Supabase database (`postgresql://postgres:postgres@127.0.0.1:54322/postgres`). To target another database, pass `--database-url=...` or set `CHURCH_DIRECTORY_DATABASE_URL` (in the shell or `.env`).

Preview the complete import transaction against the local database and roll it back:

```bash
npm run import:church-directory
```

Preview against another database:

```bash
CHURCH_DIRECTORY_DATABASE_URL='postgresql://...' npm run import:church-directory
```

Apply the validated upserts:

```bash
CHURCH_DIRECTORY_DATABASE_URL='postgresql://...' npm run import:church-directory -- \
  --apply --confirm=IMPORT_CHURCH_DIRECTORY
```

The import loads 33,653 ZIP records and approximately 17,463 geographically assigned church candidates. It skips candidates without ZIP/timezone coverage, deduplicates matching name/address/ZIP rows, and never overwrites directory fields on an administrator-verified or closed church. It does not import the source rows marked `review_required`.

## Subscription behavior

- A user can subscribe to at most three active churches.
- Subscribing again to a church the user already follows is a safe no-op: it returns `200` with `alreadySubscribed: true` and a message, and leaves the saved preferences unchanged. Only a new follow beyond three churches returns `409`.
- Creating a subscription only requires `churchId`. Omitted `serviceTypes` default to `mass`, `confession`, and `adoration`, and omitted `notificationWeekdays` default to every day. Explicit values must still contain at least one service and one weekday.
- A church without an administrator-verified schedule creates one deduplicated schedule-review task and administrator notification.
- A daily job creates a `stale_schedule` review for an active, subscribed church when its last schedule verification is at least six months old. Churches without subscribers are not periodically reverified.
- Verifying a schedule requires at least one recurring Mass time. Confession and Eucharistic adoration times are optional, and optional end times remain supported. Repeated service, weekday, and start times are collapsed.
- Administrators can add a church missing from the directory with `POST /api/v1/admin/churches` (church details plus a schedule with at least one Mass time). The church is created active and verified; an active church with the same name, address line 1, and postal code returns `409`.
- Completing the task as `verified` replaces the church's full recurring schedule and notifies subscribers. Completing it as `closed` deactivates the church, deletes its subscriptions, and notifies affected users.
- Every five minutes PostgreSQL checks for subscriptions due at or after 8:00 AM in the user's profile timezone. It creates at most one digest per subscription and local date, covering matching services over the following seven days.
- Reminder selection is per subscription. The legacy global confession and adoration preferences do not override it.

## Administrator notification email

New actionable contact requests, events, safety reports, prayer intentions,
church changes, and schedule reviews enqueue one transactional email per active
administrator account. The database queue is provider-independent, uses one
job per source/admin pair, and is processed every minute with idempotent Resend
requests and bounded retries. Bounce, complaint, and provider-suppression
records prevent delivery; marketing unsubscribes do not disable administrator
operational mail.

The public contract and examples are documented in `public/openapi.yaml` and `postman/holy-competition.postman_collection.json`.
