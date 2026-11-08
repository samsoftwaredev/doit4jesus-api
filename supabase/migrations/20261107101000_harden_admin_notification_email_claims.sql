-- Let PostgREST target the delivery log uniqueness constraint and reclaim jobs
-- left processing by an interrupted worker invocation.

drop index if exists app.email_sends_admin_notification_job_idx;
alter table app.email_sends
  drop constraint if exists email_sends_admin_notification_job_unique;
alter table app.email_sends
  add constraint email_sends_admin_notification_job_unique
  unique (admin_notification_email_job_id);

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
    where (
      (
        job.status in ('pending', 'failed')
        and job.attempt_count < 5
        and job.available_at <= now()
      )
      or (
        job.status = 'processing'
        and job.locked_at < now() - interval '10 minutes'
      )
    )
    order by job.available_at, job.created_at, job.id
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 25), 100))
  )
  update app.admin_notification_email_jobs job
  set status = 'processing',
      locked_at = now(),
      attempt_count = case
        when job.status = 'processing' then job.attempt_count
        else job.attempt_count + 1
      end,
      last_error = null
  from claimable
  where job.id = claimable.id
  returning job.*;
end;
$$;

revoke all on function app.claim_admin_notification_email_jobs(integer)
from public, anon, authenticated;
grant execute on function app.claim_admin_notification_email_jobs(integer) to service_role;
