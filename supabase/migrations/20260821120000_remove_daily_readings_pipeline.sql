-- Retire the daily-reading API pipeline. Keep this as a forward migration so
-- every deployed database also loses the scheduled worker and its stored data.

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname = 'daily-readings-ingest'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

delete from vault.secrets
where name in (
  'daily_readings_project_url',
  'daily_readings_service_role_key'
);

drop table if exists prayer.daily_readings;
