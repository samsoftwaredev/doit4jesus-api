-- Provide the Daily Rosary card with one backend-authoritative snapshot.
-- A Rosary day ends at midnight in the authenticated user's configured timezone.

create or replace function api.get_my_daily_rosary_reminder()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_timezone text;
  v_server_now timestamptz := now();
  v_today date;
  v_deadline_at timestamptz;
  v_today_rosary_completed boolean := false;
  v_last_completed_day date;
  v_streak jsonb;
  v_current_streak integer := 0;
  v_longest_streak integer := 0;
  v_streak_status text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select profile.timezone
  into v_timezone
  from app.users user_record
  join app.user_profiles profile on profile.user_id = user_record.id
  where user_record.id = v_user_id
    and user_record.deleted_at is null;

  if not found then
    raise exception 'USER_PROFILE_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_timezone := coalesce(nullif(trim(v_timezone), ''), 'UTC');

  begin
    v_today := (v_server_now at time zone v_timezone)::date;
    v_deadline_at := ((v_today + 1)::timestamp at time zone v_timezone);
  exception
    when invalid_parameter_value then
      raise exception 'USER_TIMEZONE_INVALID' using errcode = 'P0001';
  end;

  select exists(
    select 1
    from competition.spiritual_activities activity
    where activity.user_id = v_user_id
      and activity.activity_code = 'ROSARY'
      and activity.completed_at is not null
      and activity.verification_status in ('self_reported', 'verified')
      and (activity.completed_at at time zone v_timezone)::date = v_today
  )
  into v_today_rosary_completed;

  select max((activity.completed_at at time zone v_timezone)::date)
  into v_last_completed_day
  from competition.spiritual_activities activity
  where activity.user_id = v_user_id
    and activity.activity_code = 'ROSARY'
    and activity.completed_at is not null
    and activity.verification_status in ('self_reported', 'verified')
    and (activity.completed_at at time zone v_timezone)::date <= v_today;

  v_streak := app.calculate_user_rosary_streak(v_user_id, v_timezone);
  v_current_streak := coalesce((v_streak ->> 'currentStreak')::integer, 0);
  v_longest_streak := coalesce((v_streak ->> 'longestStreak')::integer, 0);

  -- A current-day completion is active. A completion yesterday is still
  -- recoverable until tonight's deadline. Once a whole local day is missed,
  -- the reminder reports a reset without mutating historical activities.
  v_streak_status := case
    when v_today_rosary_completed then 'active'
    when v_last_completed_day = v_today - 1 then 'at-risk'
    when v_last_completed_day is not null then 'reset'
    else 'none'
  end;

  return jsonb_build_object(
    'serverNow', v_server_now,
    'timezone', v_timezone,
    'todayRosaryCompleted', v_today_rosary_completed,
    'deadlineAt', v_deadline_at,
    'nextRosaryAvailableAt', case
      when v_today_rosary_completed then v_deadline_at
      else null
    end,
    'gracePeriodEndsAt', null,
    'streak', jsonb_build_object(
      'current', case when v_streak_status = 'reset' then 0 else v_current_streak end,
      'longest', v_longest_streak,
      'status', v_streak_status
    )
  );
end;
$$;

revoke all on function api.get_my_daily_rosary_reminder() from public, anon;
grant execute on function api.get_my_daily_rosary_reminder() to authenticated, service_role;
