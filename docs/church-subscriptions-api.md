# Church discovery and reminder subscriptions

The Visit Jesus in the Tabernacle backend provides authenticated U.S. postal-code discovery, nearby church search, per-church notification preferences, administrator schedule verification, and dated upcoming-service occurrences.

## Directory import

Apply the database migration before importing. The importer is pinned to the checked-in `churches_all_candidates.csv` and `zip_city_diocese_timezone.csv` hashes and validates the expected source counts.

Preview the complete import transaction and roll it back:

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
- Each subscription requires at least one of `mass`, `confession`, or `adoration` and at least one notification weekday.
- A church without an administrator-verified schedule creates one deduplicated schedule-review task and administrator notification.
- Completing the task as `verified` replaces the church's full recurring schedule and notifies subscribers. Completing it as `closed` deactivates the church, deletes its subscriptions, and notifies affected users.
- Every five minutes PostgreSQL checks for subscriptions due at or after 8:00 AM in the user's profile timezone. It creates at most one digest per subscription and local date, covering matching services over the following seven days.
- Reminder selection is per subscription. The legacy global confession and adoration preferences do not override it.

The public contract and examples are documented in `public/openapi.yaml` and `postman/holy-competition.postman_collection.json`.
