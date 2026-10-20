-- Add one continuously refreshed lifetime global Rosary leaderboard while
-- retaining yearly projections for country and friends point leaderboards.

alter table competition.leaderboard_periods
  drop constraint if exists leaderboard_periods_period_type_check;

alter table competition.leaderboard_periods
  add constraint leaderboard_periods_period_type_check
  check (period_type in ('weekly', 'yearly', 'lifetime'));

create unique index if not exists idx_leaderboard_periods_single_lifetime
  on competition.leaderboard_periods (period_type)
  where period_type = 'lifetime';

create or replace function competition.refresh_leaderboard_period(
  p_period_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_period competition.leaderboard_periods%rowtype;
  v_original_status text;
begin
  select *
  into v_period
  from competition.leaderboard_periods period_record
  where period_record.id = p_period_id
  for update;

  if not found then
    raise exception 'LEADERBOARD_PERIOD_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_period.period_type not in ('weekly', 'yearly', 'lifetime') then
    raise exception 'UNSUPPORTED_LEADERBOARD_PERIOD_TYPE' using errcode = 'P0001';
  end if;

  v_original_status := v_period.status;

  update competition.leaderboard_periods
  set status = 'calculating'
  where id = v_period.id;

  delete from competition.leaderboard_entries
  where period_id = v_period.id;

  if v_period.period_type = 'lifetime' then
    with rosary_totals as (
      select
        activity.user_id,
        sum(activity.quantity)::integer as rosaries_count
      from competition.spiritual_activities activity
      where activity.occurred_at <= v_period.ends_at
        and activity.activity_code = 'ROSARY'
        and activity.verification_status in ('self_reported', 'verified')
      group by activity.user_id
      having sum(activity.quantity) > 0
    ), ranked as (
      select
        totals.user_id,
        rank() over (order by totals.rosaries_count desc)::integer as rank,
        totals.rosaries_count
      from rosary_totals totals
    )
    insert into competition.leaderboard_entries (
      period_id,
      user_id,
      scope_type,
      scope_reference,
      points,
      rank,
      rosaries_count,
      scripture_readings_count,
      prayers_count,
      updated_at
    )
    select
      v_period.id,
      ranked.user_id,
      'global',
      'global',
      0,
      ranked.rank,
      ranked.rosaries_count,
      0,
      0,
      clock_timestamp()
    from ranked;
  else
    with participant_ids as (
      select ledger.user_id
      from competition.point_ledger ledger
      where ledger.occurred_at >= v_period.starts_at
        and ledger.occurred_at < v_period.ends_at
        and ledger.source_type <> 'legacy_balance'
      union
      select activity.user_id
      from competition.spiritual_activities activity
      where activity.occurred_at >= v_period.starts_at
        and activity.occurred_at < v_period.ends_at
        and activity.activity_code in ('ROSARY', 'SCRIPTURE', 'PRAYER')
        and activity.verification_status in ('self_reported', 'verified')
    ), point_totals as (
      select
        ledger.user_id,
        greatest(sum(ledger.points), 0::bigint) as points
      from competition.point_ledger ledger
      where ledger.occurred_at >= v_period.starts_at
        and ledger.occurred_at < v_period.ends_at
        and ledger.source_type <> 'legacy_balance'
      group by ledger.user_id
    ), activity_totals as (
      select
        activity.user_id,
        coalesce(sum(activity.quantity) filter (
          where activity.activity_code = 'ROSARY'
        ), 0)::integer as rosaries_count,
        coalesce(sum(activity.quantity) filter (
          where activity.activity_code = 'SCRIPTURE'
        ), 0)::integer as scripture_readings_count,
        coalesce(sum(activity.quantity) filter (
          where activity.activity_code = 'PRAYER'
        ), 0)::integer as prayers_count
      from competition.spiritual_activities activity
      where activity.occurred_at >= v_period.starts_at
        and activity.occurred_at < v_period.ends_at
        and activity.activity_code in ('ROSARY', 'SCRIPTURE', 'PRAYER')
        and activity.verification_status in ('self_reported', 'verified')
      group by activity.user_id
    ), totals as (
      select
        participant.user_id,
        coalesce(point_total.points, 0::bigint) as points,
        coalesce(activity_total.rosaries_count, 0) as rosaries_count,
        coalesce(activity_total.scripture_readings_count, 0) as scripture_readings_count,
        coalesce(activity_total.prayers_count, 0) as prayers_count
      from participant_ids participant
      left join point_totals point_total on point_total.user_id = participant.user_id
      left join activity_totals activity_total on activity_total.user_id = participant.user_id
    ), global_rows as (
      select
        totals.user_id,
        'global'::text as scope_type,
        'global'::varchar(150) as scope_reference,
        totals.points,
        rank() over (order by totals.rosaries_count desc)::integer as rank,
        totals.rosaries_count,
        totals.scripture_readings_count,
        totals.prayers_count
      from totals
    ), country_rows as (
      select
        totals.user_id,
        'country'::text as scope_type,
        profile.country_code::varchar(150) as scope_reference,
        totals.points,
        rank() over (
          partition by profile.country_code
          order by totals.points desc
        )::integer as rank,
        totals.rosaries_count,
        totals.scripture_readings_count,
        totals.prayers_count
      from totals
      join app.user_profiles profile on profile.user_id = totals.user_id
      where profile.country_code is not null
    ), projected_rows as (
      select * from global_rows
      union all
      select * from country_rows
    )
    insert into competition.leaderboard_entries (
      period_id,
      user_id,
      scope_type,
      scope_reference,
      points,
      rank,
      rosaries_count,
      scripture_readings_count,
      prayers_count,
      updated_at
    )
    select
      v_period.id,
      projected.user_id,
      projected.scope_type,
      projected.scope_reference,
      projected.points,
      projected.rank,
      projected.rosaries_count,
      projected.scripture_readings_count,
      projected.prayers_count,
      clock_timestamp()
    from projected_rows projected;
  end if;

  update competition.leaderboard_periods
  set status = v_original_status
  where id = v_period.id;
end;
$$;

create or replace function competition.refresh_leaderboards(
  p_backfill boolean default false,
  p_as_of timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_first_activity timestamptz;
  v_first_rosary timestamptz;
  v_current_week timestamptz;
  v_current_year timestamptz;
  v_first_week timestamptz;
  v_first_year timestamptz;
  v_period record;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('competition.refresh_leaderboards', 0)
  );

  v_current_week := pg_catalog.date_trunc(
    'week',
    p_as_of at time zone 'UTC'
  ) at time zone 'UTC';
  v_current_year := pg_catalog.date_trunc(
    'year',
    p_as_of at time zone 'UTC'
  ) at time zone 'UTC';

  select min(source_record.occurred_at)
  into v_first_activity
  from (
    select ledger.occurred_at
    from competition.point_ledger ledger
    union all
    select activity.occurred_at
    from competition.spiritual_activities activity
  ) source_record;

  v_first_activity := least(coalesce(v_first_activity, p_as_of), p_as_of);
  v_first_week := pg_catalog.date_trunc(
    'week',
    v_first_activity at time zone 'UTC'
  ) at time zone 'UTC';
  v_first_year := pg_catalog.date_trunc(
    'year',
    v_first_activity at time zone 'UTC'
  ) at time zone 'UTC';

  insert into competition.leaderboard_periods (
    period_type,
    code,
    name,
    starts_at,
    ends_at,
    status,
    finalized_at
  )
  select
    'weekly',
    'week-' || pg_catalog.to_char(
      period_start at time zone 'UTC',
      'IYYY-"W"IW'
    ),
    'Week of ' || pg_catalog.to_char(
      period_start at time zone 'UTC',
      'YYYY-MM-DD'
    ),
    period_start,
    period_start + interval '1 week',
    'scheduled',
    null
  from pg_catalog.generate_series(
    v_first_week,
    v_current_week,
    interval '1 week'
  ) period_start
  on conflict (period_type, starts_at, ends_at) do nothing;

  insert into competition.leaderboard_periods (
    period_type,
    code,
    name,
    starts_at,
    ends_at,
    status,
    finalized_at
  )
  select
    'yearly',
    'year-' || pg_catalog.to_char(
      period_start at time zone 'UTC',
      'YYYY'
    ),
    pg_catalog.to_char(period_start at time zone 'UTC', 'YYYY'),
    period_start,
    period_start + interval '1 year',
    'scheduled',
    null
  from pg_catalog.generate_series(
    v_first_year,
    v_current_year,
    interval '1 year'
  ) period_start
  on conflict (period_type, starts_at, ends_at) do nothing;

  select min(activity.occurred_at)
  into v_first_rosary
  from competition.spiritual_activities activity
  where activity.occurred_at <= p_as_of
    and activity.activity_code = 'ROSARY'
    and activity.verification_status in ('self_reported', 'verified');

  v_first_rosary := least(
    coalesce(v_first_rosary, p_as_of - interval '1 microsecond'),
    p_as_of - interval '1 microsecond'
  );

  insert into competition.leaderboard_periods (
    period_type,
    code,
    name,
    starts_at,
    ends_at,
    status,
    finalized_at
  )
  values (
    'lifetime',
    'lifetime',
    'Lifetime',
    v_first_rosary,
    p_as_of,
    'active',
    null
  )
  on conflict (code) do update
  set
    period_type = excluded.period_type,
    name = excluded.name,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    status = 'active',
    finalized_at = null;

  for v_period in
    select period_record.id
    from competition.leaderboard_periods period_record
    where (
      period_record.period_type in ('weekly', 'yearly')
      and period_record.starts_at <= p_as_of
      and (
        p_backfill
        or period_record.status in ('scheduled', 'active', 'calculating')
        or period_record.ends_at > p_as_of
      )
    ) or period_record.period_type = 'lifetime'
    order by period_record.starts_at, period_record.period_type
  loop
    perform competition.refresh_leaderboard_period(v_period.id);
  end loop;

  update competition.leaderboard_periods
  set
    status = case
      when starts_at <= p_as_of and ends_at > p_as_of then 'active'
      when ends_at <= p_as_of then 'finalized'
      else 'scheduled'
    end,
    finalized_at = case
      when ends_at <= p_as_of then coalesce(finalized_at, p_as_of)
      else null
    end
  where period_type in ('weekly', 'yearly');

  update competition.leaderboard_periods
  set status = 'active', finalized_at = null
  where period_type = 'lifetime';
end;
$$;

revoke all on function competition.refresh_leaderboard_period(uuid)
  from public, anon, authenticated;
revoke all on function competition.refresh_leaderboards(boolean, timestamptz)
  from public, anon, authenticated;

grant execute on function competition.refresh_leaderboard_period(uuid)
  to service_role;
grant execute on function competition.refresh_leaderboards(boolean, timestamptz)
  to service_role;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname in (
      'refresh-weekly-yearly-leaderboards',
      'refresh-leaderboards'
    )
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'refresh-leaderboards',
    '*/5 * * * *',
    $cron$
      select competition.refresh_leaderboards();
    $cron$
  );
end;
$$;

select competition.refresh_leaderboards(false, now());
