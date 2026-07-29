-- Confirmed friendships use a canonical user pair. Requests are retained as
-- history so cancellations and rejections do not prevent a later request.

create unique index user_profiles_username_lower_unique
  on app.user_profiles (lower(username))
  where username is not null;

create table app.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references app.users(id) on delete cascade,
  recipient_id uuid not null references app.users(id) on delete cascade,
  status text not null default 'pending',
  responded_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> recipient_id),
  check (status in ('pending', 'accepted', 'rejected', 'cancelled'))
);

create unique index friend_requests_one_pending_direction
  on app.friend_requests (requester_id, recipient_id)
  where status = 'pending';

create index friend_requests_recipient_status_created
  on app.friend_requests (recipient_id, status, created_at desc);

create index friend_requests_requester_status_created
  on app.friend_requests (requester_id, status, created_at desc);

create table app.friendships (
  id uuid primary key default gen_random_uuid(),
  user_low_id uuid not null references app.users(id) on delete cascade,
  user_high_id uuid not null references app.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_low_id < user_high_id),
  unique (user_low_id, user_high_id)
);

create index friendships_user_low on app.friendships (user_low_id, created_at desc);
create index friendships_user_high on app.friendships (user_high_id, created_at desc);

create index spiritual_activities_rosary_friend_total
  on competition.spiritual_activities (user_id)
  include (quantity)
  where activity_code = 'ROSARY'
    and verification_status in ('self_reported', 'verified');

create trigger trg_friend_requests_updated_at
before update on app.friend_requests
for each row execute function platform.set_updated_at();

alter table app.friend_requests enable row level security;
alter table app.friendships enable row level security;

grant select on app.friend_requests, app.friendships to authenticated;

create policy friend_requests_select_participant
on app.friend_requests
for select
to authenticated
using ((select auth.uid()) in (requester_id, recipient_id));

create policy friendships_select_participant
on app.friendships
for select
to authenticated
using ((select auth.uid()) in (user_low_id, user_high_id));

create or replace function app.are_users_friends(
  p_first_user_id uuid,
  p_second_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from app.friendships friendship
    where friendship.user_low_id = least(p_first_user_id, p_second_user_id)
      and friendship.user_high_id = greatest(p_first_user_id, p_second_user_id)
  );
$$;

create or replace function api.send_current_user_friend_request(
  p_username text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester_id uuid := auth.uid();
  v_recipient_id uuid;
  v_request app.friend_requests%rowtype;
  v_friendship_id uuid;
begin
  if v_requester_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_username is null or trim(p_username) = '' then
    raise exception 'INVALID_FRIEND_USERNAME' using errcode = 'P0001';
  end if;

  select profile.user_id
  into v_recipient_id
  from app.user_profiles profile
  where lower(profile.username) = lower(trim(p_username));

  if v_recipient_id is null then
    raise exception 'FRIEND_USERNAME_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_recipient_id = v_requester_id then
    raise exception 'CANNOT_FRIEND_SELF' using errcode = 'P0001';
  end if;

  if app.are_users_friends(v_requester_id, v_recipient_id) then
    raise exception 'FRIENDSHIP_ALREADY_EXISTS' using errcode = 'P0001';
  end if;

  select *
  into v_request
  from app.friend_requests request_record
  where request_record.requester_id = v_requester_id
    and request_record.recipient_id = v_recipient_id
    and request_record.status = 'pending'
  for update;

  if found then
    raise exception 'FRIEND_REQUEST_ALREADY_PENDING' using errcode = 'P0001';
  end if;

  -- A reciprocal pending request becomes a friendship immediately.
  select *
  into v_request
  from app.friend_requests request_record
  where request_record.requester_id = v_recipient_id
    and request_record.recipient_id = v_requester_id
    and request_record.status = 'pending'
  for update;

  if found then
    update app.friend_requests
    set status = 'accepted', responded_at = now(), cancelled_at = null
    where id = v_request.id;

    insert into app.friendships (user_low_id, user_high_id)
    values (
      least(v_requester_id, v_recipient_id),
      greatest(v_requester_id, v_recipient_id)
    )
    on conflict (user_low_id, user_high_id) do nothing
    returning id into v_friendship_id;

    select coalesce(
      v_friendship_id,
      (
        select friendship.id
        from app.friendships friendship
        where friendship.user_low_id = least(v_requester_id, v_recipient_id)
          and friendship.user_high_id = greatest(v_requester_id, v_recipient_id)
      )
    ) into v_friendship_id;

    insert into app.notifications (
      user_id, notification_type, title, body, action_url, payload
    )
    values (
      v_recipient_id,
      'friend_request_accepted',
      'Friend request accepted',
      'Your friend request was accepted automatically after you sent each other requests.',
      '/friends',
      jsonb_build_object('friendshipId', v_friendship_id, 'friendId', v_requester_id)
    );

    return jsonb_build_object(
      'requestId', v_request.id,
      'friendshipId', v_friendship_id,
      'status', 'accepted',
      'automatic', true
    );
  end if;

  insert into app.friend_requests (requester_id, recipient_id)
  values (v_requester_id, v_recipient_id)
  returning * into v_request;

  insert into app.notifications (
    user_id, notification_type, title, body, action_url, payload
  )
  values (
    v_recipient_id,
    'friend_request_received',
    'New friend request',
    'You have a new friend request to review.',
    '/friends/requests',
    jsonb_build_object('friendRequestId', v_request.id, 'requesterId', v_requester_id)
  );

  return jsonb_build_object(
    'requestId', v_request.id,
    'status', 'pending',
    'automatic', false
  );
end;
$$;

create or replace function api.review_current_user_friend_request(
  p_request_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient_id uuid := auth.uid();
  v_request app.friend_requests%rowtype;
  v_friendship_id uuid;
begin
  if v_recipient_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_decision is null or p_decision not in ('accepted', 'rejected') then
    raise exception 'INVALID_FRIEND_REQUEST_DECISION' using errcode = 'P0001';
  end if;

  select *
  into v_request
  from app.friend_requests request_record
  where request_record.id = p_request_id
  for update;

  if not found then
    raise exception 'FRIEND_REQUEST_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_request.recipient_id <> v_recipient_id then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'FRIEND_REQUEST_NOT_PENDING' using errcode = 'P0001';
  end if;

  update app.friend_requests
  set status = p_decision, responded_at = now(), cancelled_at = null
  where id = v_request.id;

  if p_decision = 'rejected' then
    return jsonb_build_object('requestId', v_request.id, 'status', 'rejected');
  end if;

  insert into app.friendships (user_low_id, user_high_id)
  values (
    least(v_request.requester_id, v_request.recipient_id),
    greatest(v_request.requester_id, v_request.recipient_id)
  )
  on conflict (user_low_id, user_high_id) do nothing
  returning id into v_friendship_id;

  select coalesce(
    v_friendship_id,
    (
      select friendship.id
      from app.friendships friendship
      where friendship.user_low_id = least(v_request.requester_id, v_request.recipient_id)
        and friendship.user_high_id = greatest(v_request.requester_id, v_request.recipient_id)
    )
  ) into v_friendship_id;

  update app.friend_requests
  set status = 'accepted', responded_at = now(), cancelled_at = null
  where requester_id = v_request.recipient_id
    and recipient_id = v_request.requester_id
    and status = 'pending';

  insert into app.notifications (
    user_id, notification_type, title, body, action_url, payload
  )
  values (
    v_request.requester_id,
    'friend_request_accepted',
    'Friend request accepted',
    'Your friend request was accepted.',
    '/friends',
    jsonb_build_object('friendshipId', v_friendship_id, 'friendId', v_request.recipient_id)
  );

  return jsonb_build_object(
    'requestId', v_request.id,
    'friendshipId', v_friendship_id,
    'status', 'accepted'
  );
end;
$$;

create or replace function api.cancel_current_user_friend_request(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester_id uuid := auth.uid();
  v_request app.friend_requests%rowtype;
begin
  if v_requester_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select *
  into v_request
  from app.friend_requests request_record
  where request_record.id = p_request_id
  for update;

  if not found then
    raise exception 'FRIEND_REQUEST_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_request.requester_id <> v_requester_id then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'FRIEND_REQUEST_NOT_PENDING' using errcode = 'P0001';
  end if;

  update app.friend_requests
  set status = 'cancelled', cancelled_at = now()
  where id = v_request.id;

  return jsonb_build_object('requestId', v_request.id, 'status', 'cancelled');
end;
$$;

create or replace function api.unfriend_current_user(
  p_friend_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_friendship_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  delete from app.friendships friendship
  where friendship.user_low_id = least(v_user_id, p_friend_id)
    and friendship.user_high_id = greatest(v_user_id, p_friend_id)
  returning friendship.id into v_friendship_id;

  if v_friendship_id is null then
    raise exception 'FRIENDSHIP_NOT_FOUND' using errcode = 'P0001';
  end if;

  return jsonb_build_object('friendshipId', v_friendship_id, 'friendId', p_friend_id);
end;
$$;

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
    profile.username,
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
    profile.username,
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

create or replace function api.get_current_user_friend_details(
  p_friend_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not app.are_users_friends(v_user_id, p_friend_id) then
    raise exception 'FRIENDSHIP_NOT_FOUND' using errcode = 'P0001';
  end if;

  select jsonb_build_object(
    'friend', jsonb_build_object(
      'id', profile.user_id,
      'displayName', profile.display_name,
      'username', profile.username,
      'avatarUrl', profile.avatar_url,
      'title', profile.title
    ),
    'progress', jsonb_build_object(
      'totalXp', coalesce(progress.total_xp, 0),
      'currentLevel', jsonb_build_object(
        'levelNumber', coalesce(progress.current_level, 1),
        'code', level.code,
        'name', level.name,
        'description', level.description,
        'minimumTotalXp', level.minimum_total_xp,
        'iconUrl', level.icon_url,
        'imageUrl', level.image_url
      )
    ),
    'rosaryTotal', coalesce((
      select sum(activity.quantity)::bigint
      from competition.spiritual_activities activity
      where activity.user_id = p_friend_id
        and activity.activity_code = 'ROSARY'
        and activity.verification_status in ('self_reported', 'verified')
    ), 0),
    'badges', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', user_badge.id,
          'earnedAt', user_badge.earned_at,
          'sequenceNumber', user_badge.sequence_number,
          'isFeatured', user_badge.is_featured,
          'badge', jsonb_build_object(
            'id', badge.id,
            'code', badge.code,
            'name', badge.name,
            'description', badge.description,
            'category', badge.category,
            'rarity', badge.rarity,
            'iconUrl', badge.icon_url,
            'lockedIconUrl', badge.locked_icon_url,
            'isRepeatable', badge.is_repeatable,
            'isShareable', badge.is_shareable
          )
        ) order by user_badge.earned_at desc, user_badge.id desc
      )
      from competition.user_badges user_badge
      join competition.badge_definitions badge on badge.id = user_badge.badge_id
      where user_badge.user_id = p_friend_id
    ), '[]'::jsonb)
  )
  into v_result
  from app.user_profiles profile
  left join competition.user_progress progress on progress.user_id = profile.user_id
  left join competition.level_definitions level on level.level_number = progress.current_level
  where profile.user_id = p_friend_id;

  if v_result is null then
    raise exception 'FRIENDSHIP_NOT_FOUND' using errcode = 'P0001';
  end if;

  return v_result;
end;
$$;

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

  if p_period_type not in ('daily', 'weekly', 'monthly', 'yearly', 'season') then
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
      and period_record.status in ('active', 'finalized')
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
    ),
    ranked as (
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
    ),
    paged as (
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
      'total', (select count(*) from ranked)
    )
  );
end;
$$;

revoke all on function app.are_users_friends(uuid, uuid) from public, anon, authenticated;
revoke all on function api.send_current_user_friend_request(text) from public, anon;
revoke all on function api.review_current_user_friend_request(uuid, text) from public, anon;
revoke all on function api.cancel_current_user_friend_request(uuid) from public, anon;
revoke all on function api.unfriend_current_user(uuid) from public, anon;
revoke all on function api.list_current_user_friend_requests(text, text, integer, integer) from public, anon;
revoke all on function api.list_current_user_friends(integer, integer) from public, anon;
revoke all on function api.get_current_user_friend_details(uuid) from public, anon;
revoke all on function api.get_current_user_friends_leaderboard(text, text, integer, integer) from public, anon;

grant execute on function api.send_current_user_friend_request(text) to authenticated, service_role;
grant execute on function api.review_current_user_friend_request(uuid, text) to authenticated, service_role;
grant execute on function api.cancel_current_user_friend_request(uuid) to authenticated, service_role;
grant execute on function api.unfriend_current_user(uuid) to authenticated, service_role;
grant execute on function api.list_current_user_friend_requests(text, text, integer, integer) to authenticated, service_role;
grant execute on function api.list_current_user_friends(integer, integer) to authenticated, service_role;
grant execute on function api.get_current_user_friend_details(uuid) to authenticated, service_role;
grant execute on function api.get_current_user_friends_leaderboard(text, text, integer, integer) to authenticated, service_role;
