-- Replace seeded leaderboard snapshots with database-managed weekly and yearly
-- projections. Period boundaries are always evaluated in UTC.

delete from competition.leaderboard_periods
where period_type in ('daily', 'monthly', 'season');

alter table competition.leaderboard_periods
  drop constraint if exists leaderboard_periods_period_type_check;

alter table competition.leaderboard_periods
  add constraint leaderboard_periods_period_type_check
  check (period_type in ('weekly', 'yearly'));

create unique index if not exists idx_leaderboard_periods_type_range
  on competition.leaderboard_periods (period_type, starts_at, ends_at);

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

  for v_period in
    select period_record.id
    from competition.leaderboard_periods period_record
    where period_record.period_type in ('weekly', 'yearly')
      and period_record.starts_at <= p_as_of
      and (
        p_backfill
        or period_record.status in ('scheduled', 'active', 'calculating')
        or (
          period_record.starts_at <= p_as_of
          and period_record.ends_at > p_as_of
        )
      )
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

select competition.refresh_leaderboards(true, now());

create or replace function api.get_current_user_friends_leaderboard(
  p_period_type text default 'weekly',
  p_period_code text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_period competition.leaderboard_periods%rowtype;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_period_type not in ('weekly', 'yearly') then
    raise exception 'INVALID_FRIEND_LEADERBOARD_PERIOD_TYPE' using errcode = 'P0001';
  end if;

  if p_period_code is not null then
    select *
    into v_period
    from competition.leaderboard_periods period_record
    where period_record.period_type = p_period_type
      and period_record.code = p_period_code
    limit 1;
  else
    select *
    into v_period
    from competition.leaderboard_periods period_record
    where period_record.period_type = p_period_type
      and period_record.status = 'active'
      and period_record.starts_at <= now()
      and period_record.ends_at > now()
    order by period_record.starts_at desc
    limit 1;
  end if;

  if not found then
    raise exception 'FRIEND_LEADERBOARD_PERIOD_NOT_FOUND' using errcode = 'P0001';
  end if;

  return (
    with friend_ids as (
      select v_user_id as user_id
      union
      select case
        when friendship.user_low_id = v_user_id then friendship.user_high_id
        else friendship.user_low_id
      end
      from app.friendships friendship
      where v_user_id in (friendship.user_low_id, friendship.user_high_id)
    ), ranked as (
      select
        friend_ids.user_id,
        profile.display_name,
        profile.username,
        profile.avatar_url,
        profile.title,
        coalesce(entry.points, 0) as points,
        coalesce(entry.rosaries_count, 0) as rosaries_count,
        coalesce(entry.scripture_readings_count, 0) as scripture_readings_count,
        coalesce(entry.prayers_count, 0) as prayers_count,
        rank() over (order by coalesce(entry.points, 0) desc) as rank
      from friend_ids
      join app.user_profiles profile on profile.user_id = friend_ids.user_id
      left join competition.leaderboard_entries entry
        on entry.period_id = v_period.id
        and entry.user_id = friend_ids.user_id
        and entry.scope_type = 'global'
        and entry.scope_reference = 'global'
    ), paged as (
      select *
      from ranked
      order by rank, display_name, user_id
      limit greatest(1, least(coalesce(p_limit, 50), 100))
      offset greatest(coalesce(p_offset, 0), 0)
    )
    select jsonb_build_object(
      'period', jsonb_build_object(
        'id', v_period.id,
        'periodType', v_period.period_type,
        'code', v_period.code,
        'name', v_period.name,
        'startsAt', v_period.starts_at,
        'endsAt', v_period.ends_at,
        'status', v_period.status
      ),
      'entries', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'rank', paged.rank,
            'points', paged.points,
            'rosariesCount', paged.rosaries_count,
            'scriptureReadingsCount', paged.scripture_readings_count,
            'prayersCount', paged.prayers_count,
            'isCurrentUser', paged.user_id = v_user_id,
            'friend', jsonb_build_object(
              'id', paged.user_id,
              'displayName', paged.display_name,
              'username', paged.username,
              'avatarUrl', paged.avatar_url,
              'title', paged.title
            )
          ) order by paged.rank, paged.display_name, paged.user_id
        )
        from paged
      ), '[]'::jsonb),
      'currentUserEntry', (
        select jsonb_build_object(
          'rank', current_user_record.rank,
          'points', current_user_record.points,
          'rosariesCount', current_user_record.rosaries_count,
          'scriptureReadingsCount', current_user_record.scripture_readings_count,
          'prayersCount', current_user_record.prayers_count,
          'isCurrentUser', true,
          'friend', jsonb_build_object(
            'id', current_user_record.user_id,
            'displayName', current_user_record.display_name,
            'username', current_user_record.username,
            'avatarUrl', current_user_record.avatar_url,
            'title', current_user_record.title
          )
        )
        from ranked current_user_record
        where current_user_record.user_id = v_user_id
      ),
      'total', (select count(*) from ranked)
    )
  );
end;
$$;

create or replace function api.get_current_user_friends_comparison(
  p_period_type text default 'weekly',
  p_period_code text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_period competition.leaderboard_periods%rowtype;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_period_type not in ('weekly', 'yearly') then
    raise exception 'INVALID_FRIEND_LEADERBOARD_PERIOD_TYPE' using errcode = 'P0001';
  end if;

  if p_period_code is not null then
    select *
    into v_period
    from competition.leaderboard_periods period_record
    where period_record.period_type = p_period_type
      and period_record.code = p_period_code
    limit 1;
  else
    select *
    into v_period
    from competition.leaderboard_periods period_record
    where period_record.period_type = p_period_type
      and period_record.status = 'active'
      and period_record.starts_at <= now()
      and period_record.ends_at > now()
    order by period_record.starts_at desc
    limit 1;
  end if;

  if not found then
    raise exception 'FRIEND_LEADERBOARD_PERIOD_NOT_FOUND' using errcode = 'P0001';
  end if;

  return (
    with friend_ids as (
      select v_user_id as user_id
      union
      select case
        when friendship.user_low_id = v_user_id then friendship.user_high_id
        else friendship.user_low_id
      end
      from app.friendships friendship
      where v_user_id in (friendship.user_low_id, friendship.user_high_id)
    ), ranked as (
      select
        friend_ids.user_id,
        profile.display_name,
        profile.username::varchar as username,
        profile.avatar_url,
        profile.title,
        profile.timezone,
        coalesce(entry.points, 0) as period_points,
        coalesce(entry.rosaries_count, 0) as rosaries_count,
        coalesce(entry.scripture_readings_count, 0) as scripture_readings_count,
        coalesce(entry.prayers_count, 0) as prayers_count,
        rank() over (order by coalesce(entry.points, 0) desc) as rank
      from friend_ids
      join app.user_profiles profile on profile.user_id = friend_ids.user_id
      left join competition.leaderboard_entries entry
        on entry.period_id = v_period.id
        and entry.user_id = friend_ids.user_id
        and entry.scope_type = 'global'
        and entry.scope_reference = 'global'
    ), paged as (
      select *
      from ranked
      order by rank, display_name, user_id
      limit greatest(1, least(coalesce(p_limit, 50), 100))
      offset greatest(coalesce(p_offset, 0), 0)
    )
    select jsonb_build_object(
      'period', jsonb_build_object(
        'id', v_period.id,
        'periodType', v_period.period_type,
        'code', v_period.code,
        'name', v_period.name,
        'startsAt', v_period.starts_at,
        'endsAt', v_period.ends_at,
        'status', v_period.status
      ),
      'entries', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'rank', paged.rank,
            'periodPoints', paged.period_points,
            'periodActivity', jsonb_build_object(
              'rosariesCount', paged.rosaries_count,
              'scriptureReadingsCount', paged.scripture_readings_count,
              'prayersCount', paged.prayers_count
            ),
            'isCurrentUser', paged.user_id = v_user_id,
            'profile', jsonb_build_object(
              'id', paged.user_id,
              'displayName', paged.display_name,
              'username', paged.username,
              'avatarUrl', paged.avatar_url,
              'title', paged.title
            ),
            'totalXp', coalesce(progress.total_xp, 0),
            'lifetimePoints', coalesce(progress.lifetime_points, 0),
            'currentLevel', jsonb_build_object(
              'levelNumber', coalesce(progress.current_level, 1),
              'code', level.code,
              'name', level.name
            ),
            'rosaryTotal', coalesce(rosaries.total, 0),
            'badgeCount', coalesce(badges.total, 0),
            'rosaryStreak', app.calculate_user_rosary_streak(
              paged.user_id,
              paged.timezone
            )
          )
          order by paged.rank, paged.display_name, paged.user_id
        )
        from paged
        left join competition.user_progress progress
          on progress.user_id = paged.user_id
        left join competition.level_definitions level
          on level.level_number = progress.current_level
        left join lateral (
          select sum(activity.quantity)::bigint as total
          from competition.spiritual_activities activity
          where activity.user_id = paged.user_id
            and activity.activity_code = 'ROSARY'
            and activity.verification_status in ('self_reported', 'verified')
        ) rosaries on true
        left join lateral (
          select count(*)::bigint as total
          from competition.user_badges user_badge
          where user_badge.user_id = paged.user_id
        ) badges on true
      ), '[]'::jsonb),
      'total', (select count(*) from ranked),
      'limit', greatest(1, least(coalesce(p_limit, 50), 100)),
      'offset', greatest(coalesce(p_offset, 0), 0)
    )
  );
end;
$$;

revoke all on function api.get_current_user_friends_leaderboard(
  text, text, integer, integer
) from public, anon;
revoke all on function api.get_current_user_friends_comparison(
  text, text, integer, integer
) from public, anon;

grant execute on function api.get_current_user_friends_leaderboard(
  text, text, integer, integer
) to authenticated, service_role;
grant execute on function api.get_current_user_friends_comparison(
  text, text, integer, integer
) to authenticated, service_role;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname = 'refresh-weekly-yearly-leaderboards'
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'refresh-weekly-yearly-leaderboards',
    '*/5 * * * *',
    $cron$
      select competition.refresh_leaderboards();
    $cron$
  );
end;
$$;
