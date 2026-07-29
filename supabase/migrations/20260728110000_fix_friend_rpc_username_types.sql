-- app.user_profiles.username is citext in the baseline schema. Cast it at the
-- RPC boundary so PostgREST receives the declared varchar return shape.

create or replace function api.list_current_user_friend_requests(
  p_direction text default 'incoming',
  p_status text default 'pending',
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  status text,
  direction text,
  created_at timestamptz,
  responded_at timestamptz,
  cancelled_at timestamptz,
  user_id uuid,
  display_name varchar,
  username varchar,
  avatar_url text,
  title varchar
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

  if p_direction not in ('incoming', 'outgoing', 'all') then
    raise exception 'INVALID_FRIEND_REQUEST_DIRECTION' using errcode = 'P0001';
  end if;

  if p_status not in ('pending', 'accepted', 'rejected', 'cancelled', 'all') then
    raise exception 'INVALID_FRIEND_REQUEST_STATUS' using errcode = 'P0001';
  end if;

  return query
  select
    request_record.id,
    request_record.status,
    case when request_record.recipient_id = v_user_id then 'incoming' else 'outgoing' end,
    request_record.created_at,
    request_record.responded_at,
    request_record.cancelled_at,
    profile.user_id,
    profile.display_name,
    profile.username::varchar,
    profile.avatar_url,
    profile.title
  from app.friend_requests request_record
  join app.user_profiles profile
    on profile.user_id = case
      when request_record.recipient_id = v_user_id then request_record.requester_id
      else request_record.recipient_id
    end
  where v_user_id in (request_record.requester_id, request_record.recipient_id)
    and (
      p_direction = 'all'
      or (p_direction = 'incoming' and request_record.recipient_id = v_user_id)
      or (p_direction = 'outgoing' and request_record.requester_id = v_user_id)
    )
    and (p_status = 'all' or request_record.status = p_status)
  order by request_record.created_at desc, request_record.id desc
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function api.list_current_user_friends(
  p_limit integer default 20,
  p_offset integer default 0
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
  friends_since timestamptz
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
    friend_ids.created_at
  from friend_ids
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
  order by profile.display_name, profile.user_id
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;
