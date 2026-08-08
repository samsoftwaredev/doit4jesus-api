-- Return the authenticated user's active and year-to-date longest Rosary
-- streaks. A day counts when at least one qualifying Rosary is completed on
-- that day in the user's configured timezone.

create or replace function api.get_my_rosary_streak()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_timezone text;
  v_today date;
  v_year_start date;
  v_current_end date;
  v_completed_days date[] := '{}'::date[];
  v_current_streak integer := 0;
  v_longest_streak integer := 0;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  select profile.timezone
  into v_timezone
  from app.users user_record
  join app.user_profiles profile on profile.user_id = user_record.id
  where user_record.id = v_user_id
    and user_record.deleted_at is null;

  if not found then
    raise exception 'USER_PROFILE_NOT_FOUND';
  end if;

  v_timezone := coalesce(nullif(trim(v_timezone), ''), 'UTC');

  begin
    v_today := (now() at time zone v_timezone)::date;
  exception
    when invalid_parameter_value then
      raise exception 'USER_TIMEZONE_INVALID';
  end;

  v_year_start := date_trunc('year', v_today)::date;

  select coalesce(
    array_agg(distinct (activity.completed_at at time zone v_timezone)::date),
    '{}'::date[]
  )
  into v_completed_days
  from competition.spiritual_activities activity
  where activity.user_id = v_user_id
    and activity.activity_code = 'ROSARY'
    and activity.completed_at is not null
    and activity.verification_status in ('self_reported', 'verified')
    and (activity.completed_at at time zone v_timezone)::date <= v_today;

  with grouped_days as (
    select
      activity_day,
      activity_day - (row_number() over (order by activity_day))::integer as streak_group
    from unnest(v_completed_days) as completed(activity_day)
    where activity_day >= v_year_start
  ), streaks as (
    select streak_group, count(*)::integer as streak_length
    from grouped_days
    group by streak_group
  )
  select coalesce(max(streak_length), 0)
  into v_longest_streak
  from streaks;

  v_current_end := case
    when v_today = any(v_completed_days) then v_today
    when (v_today - 1) = any(v_completed_days) then v_today - 1
    else null
  end;

  if v_current_end is not null then
    with grouped_days as (
      select
        activity_day,
        activity_day - (row_number() over (order by activity_day))::integer as streak_group
      from unnest(v_completed_days) as completed(activity_day)
    )
    select count(*)::integer
    into v_current_streak
    from grouped_days
    where streak_group = (
      select streak_group
      from grouped_days
      where activity_day = v_current_end
    );
  end if;

  return jsonb_build_object(
    'currentStreak', v_current_streak,
    'longestStreak', v_longest_streak,
    'asOfDate', v_today,
    'timezone', v_timezone
  );
end;
$$;

revoke all on function api.get_my_rosary_streak() from public, anon;
grant execute on function api.get_my_rosary_streak() to authenticated, service_role;
