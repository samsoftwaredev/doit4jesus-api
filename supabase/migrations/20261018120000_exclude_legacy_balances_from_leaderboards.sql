-- A legacy XP balance is an all-time snapshot without event-level timing. Keep
-- it in the auditable point ledger without attributing the entire balance to
-- the week and year in which the snapshot happened to be imported.

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

  if v_period.period_type not in ('weekly', 'yearly') then
    raise exception 'UNSUPPORTED_LEADERBOARD_PERIOD_TYPE' using errcode = 'P0001';
  end if;

  v_original_status := v_period.status;

  update competition.leaderboard_periods
  set status = 'calculating'
  where id = v_period.id;

  delete from competition.leaderboard_entries
  where period_id = v_period.id;

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
      rank() over (order by totals.points desc)::integer as rank,
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

  update competition.leaderboard_periods
  set status = v_original_status
  where id = v_period.id;
end;
$$;

revoke all on function competition.refresh_leaderboard_period(uuid)
from public, anon, authenticated;

grant execute on function competition.refresh_leaderboard_period(uuid)
to service_role;
