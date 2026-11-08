-- Run against the local seeded database. Every data change is rolled back.
begin;

do $$
declare
  v_trigger_count integer;
  v_enqueued integer;
  v_stale_count integer;
begin
  select count(*) into v_trigger_count
  from information_schema.triggers
  where trigger_name in (
    'trg_contact_requests_admin_email',
    'trg_events_admin_email',
    'trg_content_reports_admin_email',
    'trg_prayer_intentions_admin_email',
    'trg_church_change_requests_admin_email',
    'trg_church_schedule_reviews_admin_email'
  );
  if v_trigger_count <> 6 then
    raise exception 'Expected six administrator email triggers, found %', v_trigger_count;
  end if;

  v_enqueued := app.enqueue_admin_notification_email(
    'contact_request',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'Test administrator notification',
    'This delivery is rolled back.',
    '/dashboard?tab=admin&panel=contacts',
    '{}'::jsonb
  );
  if v_enqueued < 1 then
    raise exception 'Expected at least one active administrator email delivery';
  end if;
  if not exists (
    select 1 from app.admin_notification_email_jobs job
    join app.user_roles role_record on role_record.user_id = job.recipient_user_id
    where job.source_id = 'aaaaaaaa-0000-4000-8000-000000000001'
      and role_record.role = 'admin'
  ) then
    raise exception 'Administrator delivery job was not persisted';
  end if;

  insert into app.email_sends (
    admin_notification_email_job_id, kind, recipient_email, resend_email_id
  )
  select job.id, 'admin_notification', job.recipient_email, 'test-' || job.id::text
  from app.admin_notification_email_jobs job
  where job.source_id = 'aaaaaaaa-0000-4000-8000-000000000001'
  on conflict (admin_notification_email_job_id) do update
  set resend_email_id = excluded.resend_email_id;

  update app.admin_notification_email_jobs
  set status = 'sent', sent_at = now()
  where source_id <> 'aaaaaaaa-0000-4000-8000-000000000001';
  update app.admin_notification_email_jobs
  set status = 'processing', locked_at = now() - interval '11 minutes',
      attempt_count = 1
  where source_id = 'aaaaaaaa-0000-4000-8000-000000000001';
  perform app.claim_admin_notification_email_jobs(25);
  if not exists (
    select 1 from app.admin_notification_email_jobs
    where source_id = 'aaaaaaaa-0000-4000-8000-000000000001'
      and status = 'processing' and locked_at > now() - interval '1 minute'
  ) then
    raise exception 'Interrupted administrator email job was not reclaimed';
  end if;

  delete from app.church_schedule_review_tasks
  where church_id = 'c6000000-0000-4000-8000-000000000001' and status = 'pending';
  update app.churches
  set schedule_verified_at = now() - interval '6 months 1 day', is_active = true
  where id = 'c6000000-0000-4000-8000-000000000001';

  v_stale_count := app.enqueue_stale_church_schedule_reviews();
  if v_stale_count < 1 or not exists (
    select 1 from app.church_schedule_review_tasks
    where church_id = 'c6000000-0000-4000-8000-000000000001'
      and status = 'pending' and request_reason = 'stale_schedule'
  ) then
    raise exception 'Subscribed stale church did not receive a review task';
  end if;

  v_stale_count := app.enqueue_stale_church_schedule_reviews();
  if v_stale_count <> 0 then
    raise exception 'Stale church task was not deduplicated';
  end if;

  delete from app.church_subscriptions
  where church_id = 'c6000000-0000-4000-8000-000000000004';
  delete from app.church_schedule_review_tasks
  where church_id = 'c6000000-0000-4000-8000-000000000004' and status = 'pending';
  update app.churches
  set schedule_verified_at = now() - interval '1 year', is_active = true
  where id = 'c6000000-0000-4000-8000-000000000004';
  perform app.enqueue_stale_church_schedule_reviews();
  if exists (
    select 1 from app.church_schedule_review_tasks
    where church_id = 'c6000000-0000-4000-8000-000000000004'
      and status = 'pending'
  ) then
    raise exception 'Unsubscribed church incorrectly received a stale review task';
  end if;
end;
$$;

rollback;
