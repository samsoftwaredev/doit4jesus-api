-- Church schedule reverification and reliable administrator notification email queue.

alter table app.church_schedule_review_tasks
  add column if not exists request_reason text not null default 'missing_schedule';

alter table app.church_schedule_review_tasks
  drop constraint if exists church_schedule_review_tasks_request_reason_check;
alter table app.church_schedule_review_tasks
  add constraint church_schedule_review_tasks_request_reason_check
  check (request_reason in ('missing_schedule', 'stale_schedule'));

create table app.admin_notification_email_jobs (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  source_id uuid not null,
  recipient_user_id uuid not null references app.users(id) on delete cascade,
  recipient_email public.citext not null,
  subject text not null,
  body text not null,
  action_url text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  sent_at timestamptz,
  resend_email_id text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint admin_notification_email_jobs_category_check check (
    category in (
      'contact_request', 'event', 'safety_report', 'prayer_intention',
      'church_change_request', 'church_schedule_review'
    )
  ),
  constraint admin_notification_email_jobs_status_check
    check (status in ('pending', 'processing', 'sent', 'failed')),
  constraint admin_notification_email_jobs_attempt_check
    check (attempt_count between 0 and 5),
  constraint admin_notification_email_jobs_payload_check
    check (jsonb_typeof(payload) = 'object'),
  constraint admin_notification_email_jobs_unique_delivery
    unique (category, source_id, recipient_user_id)
);

create index admin_notification_email_jobs_pending_idx
on app.admin_notification_email_jobs (available_at, created_at, id)
where status in ('pending', 'failed') and attempt_count < 5;

create trigger trg_admin_notification_email_jobs_updated_at
before update on app.admin_notification_email_jobs
for each row execute function platform.set_updated_at();

alter table app.admin_notification_email_jobs enable row level security;
revoke all on app.admin_notification_email_jobs from anon, authenticated;
grant select on app.admin_notification_email_jobs to authenticated;
grant all on app.admin_notification_email_jobs to service_role;

create policy admin_notification_email_jobs_select_admin
on app.admin_notification_email_jobs for select to authenticated
using (app.is_current_user_admin());

alter table app.email_sends
  add column if not exists admin_notification_email_job_id uuid
  references app.admin_notification_email_jobs(id) on delete set null;

alter table app.email_sends drop constraint if exists email_sends_kind_check;
alter table app.email_sends add constraint email_sends_kind_check
  check (kind in ('campaign', 'test', 'reply', 'admin_notification'));
alter table app.email_sends drop constraint if exists email_sends_check;
alter table app.email_sends drop constraint if exists email_sends_source_check;
alter table app.email_sends add constraint email_sends_source_check check (
  (kind = 'campaign' and campaign_id is not null)
  or (kind = 'test' and campaign_id is not null and test_run_id is not null)
  or (kind = 'reply' and contact_request_id is not null)
  or (kind = 'admin_notification' and admin_notification_email_job_id is not null)
);
create unique index if not exists email_sends_admin_notification_job_idx
on app.email_sends (admin_notification_email_job_id)
where admin_notification_email_job_id is not null;

create or replace function app.enqueue_admin_notification_email(
  p_category text,
  p_source_id uuid,
  p_subject text,
  p_body text,
  p_action_url text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  insert into app.admin_notification_email_jobs (
    category, source_id, recipient_user_id, recipient_email,
    subject, body, action_url, payload
  )
  select
    p_category, p_source_id, role_record.user_id, lower(app_user.email),
    p_subject, p_body, p_action_url, coalesce(p_payload, '{}'::jsonb)
  from app.user_roles role_record
  join app.users app_user on app_user.id = role_record.user_id
  where role_record.role = 'admin'
    and app_user.status = 'active'
    and app_user.deleted_at is null
    and app_user.email is not null
    and btrim(app_user.email) <> ''
    and not exists (
      select 1 from app.email_suppressions suppression
      where lower(suppression.email::text) = lower(app_user.email)
        and suppression.reason in ('bounce', 'complaint', 'suppressed')
    )
  on conflict (category, source_id, recipient_user_id) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function app.enqueue_admin_notification_email(text, uuid, text, text, text, jsonb)
from public, anon, authenticated;
grant execute on function app.enqueue_admin_notification_email(text, uuid, text, text, text, jsonb)
to service_role;

create or replace function app.enqueue_admin_notification_email_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_record jsonb := to_jsonb(new);
  v_category text;
  v_subject text;
  v_body text;
  v_action_url text;
begin
  if tg_table_schema = 'app' and tg_table_name = 'contact_requests' then
    if coalesce(v_record ->> 'status', 'todo') not in ('todo', 'inprogress') then return new; end if;
    v_category := 'contact_request';
    v_subject := 'New contact request: ' || coalesce(v_record ->> 'subject', 'General request');
    v_body := coalesce(v_record ->> 'name', 'A visitor') || ' submitted a contact request for administrator review.';
    v_action_url := '/dashboard?tab=admin&panel=contacts';
  elsif tg_table_schema = 'app' and tg_table_name = 'events' then
    if v_record ->> 'status' <> 'pending' then return new; end if;
    v_category := 'event';
    v_subject := 'New event awaiting review';
    v_body := coalesce(v_record ->> 'title', 'An event') || ' was submitted for administrator review.';
    v_action_url := '/dashboard?tab=admin&panel=events';
  elsif tg_table_schema = 'app' and tg_table_name = 'content_reports' then
    if v_record ->> 'status' <> 'open' then return new; end if;
    v_category := 'safety_report';
    v_subject := 'New safety report awaiting review';
    v_body := 'A ' || replace(coalesce(v_record ->> 'target_type', 'content'), '_', ' ') || ' report requires administrator review.';
    v_action_url := '/dashboard?tab=admin&panel=reports';
  elsif tg_table_schema = 'prayer' and tg_table_name = 'prayer_intentions' then
    if v_record ->> 'status' <> 'pending' then return new; end if;
    v_category := 'prayer_intention';
    v_subject := 'New prayer intention awaiting review';
    v_body := coalesce(v_record ->> 'title', 'A prayer intention') || ' was submitted for administrator review.';
    v_action_url := '/dashboard?tab=admin&panel=prayers';
  elsif tg_table_schema = 'app' and tg_table_name = 'church_change_requests' then
    if v_record ->> 'status' <> 'pending' then return new; end if;
    v_category := 'church_change_request';
    v_subject := 'New church change awaiting review';
    v_body := 'A ' || replace(coalesce(v_record ->> 'request_type', 'church change'), '_', ' ') || ' request requires administrator review.';
    v_action_url := '/dashboard?tab=admin&panel=churches&churchView=changes';
  elsif tg_table_schema = 'app' and tg_table_name = 'church_schedule_review_tasks' then
    if v_record ->> 'status' <> 'pending' then return new; end if;
    v_category := 'church_schedule_review';
    v_subject := case v_record ->> 'request_reason'
      when 'stale_schedule' then 'Church schedule needs reverification'
      else 'Church schedule needs to be entered'
    end;
    v_body := case v_record ->> 'request_reason'
      when 'stale_schedule' then 'A followed church has a schedule that is at least six months old.'
      else 'A followed church does not have a verified Mass, confession, and adoration schedule.'
    end;
    v_action_url := '/dashboard?tab=admin&panel=churches&churchView=schedules';
  else
    return new;
  end if;

  perform app.enqueue_admin_notification_email(
    v_category,
    (v_record ->> 'id')::uuid,
    v_subject,
    v_body,
    v_action_url,
    jsonb_build_object('sourceId', v_record ->> 'id', 'category', v_category)
  );
  return new;
end;
$$;

revoke all on function app.enqueue_admin_notification_email_trigger() from public, anon, authenticated;

create trigger trg_contact_requests_admin_email
after insert on app.contact_requests for each row
execute function app.enqueue_admin_notification_email_trigger();
create trigger trg_events_admin_email
after insert on app.events for each row
execute function app.enqueue_admin_notification_email_trigger();
create trigger trg_content_reports_admin_email
after insert on app.content_reports for each row
execute function app.enqueue_admin_notification_email_trigger();
create trigger trg_prayer_intentions_admin_email
after insert on prayer.prayer_intentions for each row
execute function app.enqueue_admin_notification_email_trigger();
create trigger trg_church_change_requests_admin_email
after insert on app.church_change_requests for each row
execute function app.enqueue_admin_notification_email_trigger();
create trigger trg_church_schedule_reviews_admin_email
after insert on app.church_schedule_review_tasks for each row
execute function app.enqueue_admin_notification_email_trigger();

create or replace function app.claim_admin_notification_email_jobs(p_limit integer default 25)
returns setof app.admin_notification_email_jobs
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with claimable as (
    select job.id
    from app.admin_notification_email_jobs job
    where job.status in ('pending', 'failed')
      and job.attempt_count < 5
      and job.available_at <= now()
    order by job.available_at, job.created_at, job.id
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 25), 100))
  )
  update app.admin_notification_email_jobs job
  set status = 'processing', locked_at = now(), attempt_count = job.attempt_count + 1,
      last_error = null
  from claimable
  where job.id = claimable.id
  returning job.*;
end;
$$;

revoke all on function app.claim_admin_notification_email_jobs(integer)
from public, anon, authenticated;
grant execute on function app.claim_admin_notification_email_jobs(integer) to service_role;

create or replace function app.enqueue_stale_church_schedule_reviews()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  insert into app.church_schedule_review_tasks (church_id, requested_by, request_reason)
  select church.id, null, 'stale_schedule'
  from app.churches church
  where church.is_active
    and church.schedule_verified_at is not null
    and church.schedule_verified_at <= now() - interval '6 months'
    and exists (
      select 1 from app.church_subscriptions subscription
      where subscription.church_id = church.id
    )
  on conflict (church_id) where status = 'pending' do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function app.enqueue_stale_church_schedule_reviews()
from public, anon, authenticated;
grant execute on function app.enqueue_stale_church_schedule_reviews() to service_role;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname = 'reverify-stale-church-schedules';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'reverify-stale-church-schedules',
    '5 6 * * *',
    'select app.enqueue_stale_church_schedule_reviews();'
  );

  select jobid into v_job_id from cron.job where jobname = 'process-admin-notification-emails';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'process-admin-notification-emails',
    '* * * * *',
    $cron$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'admin_notification_app_url')
          || '/api/v1/internal/admin-notification-emails/process',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (
            select decrypted_secret from vault.decrypted_secrets
            where name = 'admin_notification_worker_secret'
          )
        ),
        body := '{}'::jsonb
      );
    $cron$
  );
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'app'
      and tablename = 'church_schedule_review_tasks'
  ) then
    alter publication supabase_realtime add table app.church_schedule_review_tasks;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'app'
      and tablename = 'content_reports'
  ) then
    alter publication supabase_realtime add table app.content_reports;
  end if;
end;
$$;

create or replace function api.review_church_schedule_task(
  p_review_id uuid,
  p_decision text,
  p_church jsonb default '{}'::jsonb,
  p_service_times jsonb default '[]'::jsonb,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_task app.church_schedule_review_tasks%rowtype;
begin
  if v_admin_id is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;
  if not app.is_current_user_admin() then raise exception 'FORBIDDEN' using errcode = 'P0001'; end if;
  if p_decision not in ('verified', 'closed') then
    raise exception 'INVALID_CHURCH_SCHEDULE_DECISION' using errcode = 'P0001';
  end if;

  select * into v_task from app.church_schedule_review_tasks task
  where task.id = p_review_id for update;
  if not found then raise exception 'CHURCH_SCHEDULE_REVIEW_NOT_FOUND' using errcode = 'P0001'; end if;
  if v_task.status <> 'pending' then raise exception 'CHURCH_SCHEDULE_REVIEW_NOT_PENDING' using errcode = 'P0001'; end if;

  perform 1 from app.churches church where church.id = v_task.church_id for update;
  if not found then raise exception 'CHURCH_NOT_FOUND' using errcode = 'P0001'; end if;

  if p_decision = 'verified' then
    if jsonb_typeof(p_service_times) <> 'array'
      or jsonb_array_length(p_service_times) = 0
      or not ('mass' = any(array(select item ->> 'service_type' from jsonb_array_elements(p_service_times) item)))
      or not ('confession' = any(array(select item ->> 'service_type' from jsonb_array_elements(p_service_times) item)))
      or not ('adoration' = any(array(select item ->> 'service_type' from jsonb_array_elements(p_service_times) item))) then
      raise exception 'INCOMPLETE_CHURCH_SERVICE_TIMES' using errcode = 'P0001';
    end if;

    update app.churches
    set
      name = coalesce(nullif(btrim(p_church ->> 'name'), ''), name),
      address_line_1 = coalesce(nullif(btrim(p_church ->> 'address_line_1'), ''), address_line_1),
      address_line_2 = case when p_church ? 'address_line_2' then nullif(btrim(p_church ->> 'address_line_2'), '') else address_line_2 end,
      city = coalesce(nullif(btrim(p_church ->> 'city'), ''), city),
      region_name = case when p_church ? 'region_name' then nullif(btrim(p_church ->> 'region_name'), '') else region_name end,
      postal_code = case when p_church ? 'postal_code' then nullif(btrim(p_church ->> 'postal_code'), '') else postal_code end,
      country_code = coalesce(nullif(upper(btrim(p_church ->> 'country_code')), '')::char(2), country_code),
      timezone = coalesce(nullif(btrim(p_church ->> 'timezone'), ''), timezone),
      latitude = case when p_church ? 'latitude' then (p_church ->> 'latitude')::numeric else latitude end,
      longitude = case when p_church ? 'longitude' then (p_church ->> 'longitude')::numeric else longitude end,
      diocese_id = case when p_church ? 'diocese_id' then nullif(p_church ->> 'diocese_id', '')::uuid else diocese_id end,
      is_active = true,
      directory_verification_status = 'verified',
      directory_verified_at = now(),
      directory_verified_by = v_admin_id
    where id = v_task.church_id;

    delete from app.church_service_times where church_id = v_task.church_id;
    insert into app.church_service_times (church_id, service_type, weekday, starts_at, ends_at)
    select v_task.church_id, proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at
    from jsonb_to_recordset(p_service_times) as proposed(
      service_type text, weekday smallint, starts_at time, ends_at time
    );

    update app.churches
    set schedule_verified_at = now(), schedule_verified_by = v_admin_id
    where id = v_task.church_id;

    insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
    select subscription.user_id, 'church_schedule_verified', 'Church schedule available',
      'Mass, confession, and adoration times are now available for a church you follow.',
      format('/churches/%s', v_task.church_id),
      jsonb_build_object('churchId', v_task.church_id, 'reviewId', v_task.id)
    from app.church_subscriptions subscription
    where subscription.church_id = v_task.church_id;
  else
    update app.churches
    set is_active = false, directory_verification_status = 'closed',
      directory_verified_at = now(), directory_verified_by = v_admin_id,
      schedule_verified_at = null, schedule_verified_by = null
    where id = v_task.church_id;

    insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
    select subscription.user_id, 'church_closed', 'Church subscription removed',
      'A church you followed was confirmed closed and has been removed from your subscriptions.',
      null, jsonb_build_object('churchId', v_task.church_id, 'reviewId', v_task.id)
    from app.church_subscriptions subscription
    where subscription.church_id = v_task.church_id;

    delete from app.church_subscriptions where church_id = v_task.church_id;
  end if;

  update app.church_schedule_review_tasks
  set status = 'completed', outcome = p_decision,
    completion_reason = nullif(btrim(p_reason), ''), completed_by = v_admin_id,
    completed_at = now()
  where id = v_task.id;

  return jsonb_build_object('reviewId', v_task.id, 'churchId', v_task.church_id, 'outcome', p_decision);
end;
$$;

revoke all on function api.review_church_schedule_task(uuid, text, jsonb, jsonb, text)
from public, anon;
grant execute on function api.review_church_schedule_task(uuid, text, jsonb, jsonb, text)
to authenticated, service_role;
