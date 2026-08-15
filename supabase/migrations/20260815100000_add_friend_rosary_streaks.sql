-- Reuse the same timezone-aware Rosary streak rules for the current user's
-- streak endpoint and the opt-in friend-card streaks. The helper is private to
-- database functions; callers must pass their friendship authorization first.

create or replace function app.calculate_user_rosary_streak(
  p_user_id uuid,
  p_timezone text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_timezone text := coalesce(nullif(trim(p_timezone), ''), 'UTC');
  v_today date;
  v_year_start date;
  v_current_end date;
  v_completed_days date[] := '{}'::date[];
  v_current_streak integer := 0;
  v_longest_streak integer := 0;
begin
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
  where activity.user_id = p_user_id
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

revoke all on function app.calculate_user_rosary_streak(uuid, text)
  from public, anon, authenticated;

create or replace function api.get_my_rosary_streak()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_timezone text;
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

  return app.calculate_user_rosary_streak(v_user_id, v_timezone);
end;
$$;

drop function api.list_current_user_friends(integer, integer);

create function api.list_current_user_friends(
  p_limit integer default 20,
  p_offset integer default 0,
  p_include_rosary_streak boolean default false
)
returns table (
  friend_id uuid,
  display_name varchar,
  username varchar,
  avatar_url text,
  title varchar,
  total_xp bigint,
  current_level integer,
  level_code varchar,
  level_name varchar,
  rosary_total bigint,
  badge_count bigint,
  friends_since timestamptz,
  rosary_streak jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  return query
  with friend_ids as (
    select case
      when friendship.user_low_id = v_user_id then friendship.user_high_id
      else friendship.user_low_id
    end as id,
    friendship.created_at
    from app.friendships friendship
    where v_user_id in (friendship.user_low_id, friendship.user_high_id)
  ), paged_friend_ids as materialized (
    select friend_ids.id, friend_ids.created_at
    from friend_ids
    join app.user_profiles profile on profile.user_id = friend_ids.id
    order by profile.display_name, profile.user_id
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    offset greatest(coalesce(p_offset, 0), 0)
  )
  select
    friend_ids.id,
    profile.display_name,
    profile.username::varchar,
    profile.avatar_url,
    profile.title,
    coalesce(progress.total_xp, 0),
    coalesce(progress.current_level, 1),
    level.code,
    level.name,
    coalesce(rosaries.total, 0),
    coalesce(badges.total, 0),
    friend_ids.created_at,
    case
      when p_include_rosary_streak then app.calculate_user_rosary_streak(
        friend_ids.id,
        profile.timezone
      )
      else null
    end
  from paged_friend_ids friend_ids
  join app.user_profiles profile on profile.user_id = friend_ids.id
  left join competition.user_progress progress on progress.user_id = friend_ids.id
  left join competition.level_definitions level on level.level_number = progress.current_level
  left join lateral (
    select sum(activity.quantity)::bigint as total
    from competition.spiritual_activities activity
    where activity.user_id = friend_ids.id
      and activity.activity_code = 'ROSARY'
      and activity.verification_status in ('self_reported', 'verified')
  ) rosaries on true
  left join lateral (
    select count(*)::bigint as total
    from competition.user_badges user_badge
    where user_badge.user_id = friend_ids.id
  ) badges on true
  order by profile.display_name, profile.user_id;
end;
$$;

revoke all on function api.list_current_user_friends(integer, integer, boolean)
  from public, anon;
grant execute on function api.list_current_user_friends(integer, integer, boolean)
  to authenticated, service_role;
