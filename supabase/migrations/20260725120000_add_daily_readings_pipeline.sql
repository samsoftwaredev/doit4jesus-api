-- Daily liturgical-reading catalogue. The import workers store only the
-- application data required to render a day; they do not persist feed URLs,
-- GUIDs, timestamps, or raw feed payloads.

create table prayer.daily_readings (
  id uuid primary key default gen_random_uuid(),
  reading_date date not null,
  celebration_name text not null,
  lectionary_number integer,
  scripture_references jsonb not null default '[]'::jsonb,
  scripture_text jsonb not null default '[]'::jsonb,
  text_status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_readings_date_key unique (reading_date),
  constraint daily_readings_lectionary_number_check
    check (lectionary_number is null or lectionary_number > 0),
  constraint daily_readings_scripture_references_array_check
    check (jsonb_typeof(scripture_references) = 'array'),
  constraint daily_readings_scripture_text_array_check
    check (jsonb_typeof(scripture_text) = 'array'),
  constraint daily_readings_text_status_check
    check (text_status in ('pending', 'complete', 'partial', 'failed'))
);

create index idx_daily_readings_text_status_date
  on prayer.daily_readings (text_status, reading_date desc);

create trigger trg_daily_readings_updated_at
before update on prayer.daily_readings
for each row execute function platform.set_updated_at();

alter table prayer.daily_readings enable row level security;

revoke all privileges on table prayer.daily_readings from anon, authenticated;
grant select on table prayer.daily_readings to authenticated;
grant all privileges on table prayer.daily_readings to service_role;

create policy daily_readings_select_authenticated
on prayer.daily_readings
for select
to authenticated
using (true);

-- The import runs at 12:15 UTC: after the upstream daily publication in both
-- US daylight- and standard-time periods. It invokes the ingest worker only;
-- that worker calls the text-enrichment worker after its database upsert has
-- completed, so the second stage cannot race the first.
--
-- Before the first production run, create these Vault secrets:
--   daily_readings_project_url
--   daily_readings_service_role_key
-- They are deliberately referenced at job runtime rather than committed.
do $$
declare
  v_existing_job_id bigint;
begin
  select jobid
  into v_existing_job_id
  from cron.job
  where jobname = 'daily-readings-ingest';

  if v_existing_job_id is not null then
    perform cron.unschedule(v_existing_job_id);
  end if;

  perform cron.schedule(
    'daily-readings-ingest',
    '15 12 * * *',
    $cron$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'daily_readings_project_url'
        ) || '/functions/v1/daily-readings-ingest',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'apikey', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'daily_readings_service_role_key'
          ),
          'Authorization', 'Bearer ' || (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'daily_readings_service_role_key'
          )
        ),
        body := '{}'::jsonb
      );
    $cron$
  );
end;
$$;
