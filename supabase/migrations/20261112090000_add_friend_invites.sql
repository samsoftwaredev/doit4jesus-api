-- Personal friend-invite links, public (non-friend) profile lookups, and
-- notification read helpers for the app's bell badge.

create table if not exists app.friend_invites (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null unique references app.users(id) on delete cascade,
  code text not null unique check (code ~ '^[A-Za-z0-9_-]{12,64}$'),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

alter table app.friend_invites enable row level security;

revoke all on app.friend_invites from anon, authenticated;
grant select on app.friend_invites to authenticated;
grant all on app.friend_invites to service_role;

drop policy if exists friend_invites_select_own on app.friend_invites;
create policy friend_invites_select_own
on app.friend_invites
for select
to authenticated
using ((select auth.uid()) = inviter_id);

-- Returns the caller's reusable invite code, creating it on first use.
create or replace function api.get_current_user_friend_invite()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select invite.code into v_code
  from app.friend_invites invite
  where invite.inviter_id = v_user_id and invite.revoked_at is null;

  if v_code is null then
    -- Regenerates when a previously revoked code exists for the user.
    delete from app.friend_invites
    where inviter_id = v_user_id and revoked_at is not null;

    insert into app.friend_invites (inviter_id, code)
    values (
      v_user_id,
      translate(encode(extensions.gen_random_bytes(12), 'base64'), '+/=', '-_')
    )
    on conflict (inviter_id) do nothing;

    select invite.code into v_code
    from app.friend_invites invite
    where invite.inviter_id = v_user_id and invite.revoked_at is null;
  end if;

  return jsonb_build_object('code', v_code);
end;
$$;

-- Shows who owns an invite code. Unknown, revoked, own, and blocked codes are
-- indistinguishable "not found" results.
create or replace function api.get_friend_invite_preview(p_code text)
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

  select jsonb_build_object(
    'inviter', jsonb_build_object(
      'id', profile.user_id,
      'username', profile.username,
      'displayName', profile.display_name,
      'avatarUrl', profile.avatar_url,
      'title', profile.title
    ),
    'relationshipState', case
      when app.are_users_friends(v_user_id, invite.inviter_id) then 'friends'
      else 'none'
    end
  )
  into v_result
  from app.friend_invites invite
  join app.user_profiles profile on profile.user_id = invite.inviter_id
  join app.users user_record
    on user_record.id = invite.inviter_id
    and user_record.status = 'active'
    and user_record.deleted_at is null
  where invite.code = p_code
    and invite.revoked_at is null
    and invite.inviter_id <> v_user_id
    and not app.users_are_blocked(v_user_id, invite.inviter_id);

  if v_result is null then
    raise exception 'FRIEND_INVITE_NOT_FOUND' using errcode = 'P0001';
  end if;

  return v_result;
end;
$$;

-- Accepting an invite creates the friendship immediately. Repeating it is safe.
create or replace function api.accept_friend_invite(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_inviter_id uuid;
  v_friendship_id uuid;
  v_already_friends boolean;
  v_accepter_name text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select invite.inviter_id into v_inviter_id
  from app.friend_invites invite
  join app.users user_record
    on user_record.id = invite.inviter_id
    and user_record.status = 'active'
    and user_record.deleted_at is null
  where invite.code = p_code and invite.revoked_at is null;

  if v_inviter_id is null
    or app.users_are_blocked(v_user_id, v_inviter_id) then
    raise exception 'FRIEND_INVITE_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_inviter_id = v_user_id then
    raise exception 'CANNOT_FRIEND_SELF' using errcode = 'P0001';
  end if;

  v_already_friends := app.are_users_friends(v_user_id, v_inviter_id);

  if not v_already_friends then
    update app.friend_requests
    set status = 'accepted', responded_at = now(), cancelled_at = null
    where status = 'pending'
      and (
        (requester_id = v_user_id and recipient_id = v_inviter_id)
        or (requester_id = v_inviter_id and recipient_id = v_user_id)
      );

    insert into app.friendships (user_low_id, user_high_id)
    values (
      least(v_user_id, v_inviter_id),
      greatest(v_user_id, v_inviter_id)
    )
    on conflict (user_low_id, user_high_id) do nothing;

    select coalesce(profile.display_name, profile.username)
    into v_accepter_name
    from app.user_profiles profile
    where profile.user_id = v_user_id;

    insert into app.notifications (
      user_id, notification_type, title, body, action_url, payload
    )
    values (
      v_inviter_id,
      'friend_invite_accepted',
      'New friend',
      coalesce(v_accepter_name, 'Someone') || ' joined you through your invite link.',
      '/friends',
      jsonb_build_object('friendId', v_user_id)
    );
  end if;

  select friendship.id into v_friendship_id
  from app.friendships friendship
  where friendship.user_low_id = least(v_user_id, v_inviter_id)
    and friendship.user_high_id = greatest(v_user_id, v_inviter_id);

  return jsonb_build_object(
    'friendshipId', v_friendship_id,
    'friendId', v_inviter_id,
    'status', case when v_already_friends then 'alreadyFriends' else 'accepted' end
  );
end;
$$;

-- Public profile for any non-blocked active user, found by username. Rosary
-- streak details stay friends-only.
create or replace function api.get_user_public_profile(p_username text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_target_id uuid;
  v_result jsonb;
  v_request_id uuid;
  v_state text;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select profile.user_id into v_target_id
  from app.user_profiles profile
  join app.users user_record
    on user_record.id = profile.user_id
    and user_record.status = 'active'
    and user_record.deleted_at is null
  where lower(profile.username::text) = lower(trim(p_username));

  if v_target_id is null
    or v_target_id = v_user_id
    or app.users_are_blocked(v_user_id, v_target_id) then
    raise exception 'FRIEND_USERNAME_NOT_FOUND' using errcode = 'P0001';
  end if;

  if app.are_users_friends(v_user_id, v_target_id) then
    v_state := 'friends';
  else
    select request_record.id,
      case when request_record.requester_id = v_user_id
        then 'outgoingPending' else 'incomingPending' end
    into v_request_id, v_state
    from app.friend_requests request_record
    where request_record.status = 'pending'
      and (
        (request_record.requester_id = v_user_id
          and request_record.recipient_id = v_target_id)
        or (request_record.requester_id = v_target_id
          and request_record.recipient_id = v_user_id)
      )
    order by request_record.created_at desc
    limit 1;
    v_state := coalesce(v_state, 'none');
  end if;

  select jsonb_build_object(
    'user', jsonb_build_object(
      'id', profile.user_id,
      'displayName', profile.display_name,
      'username', profile.username,
      'avatarUrl', profile.avatar_url,
      'title', profile.title,
      'countryCode', profile.country_code
    ),
    'relationshipState', v_state,
    'requestId', v_request_id,
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
      where activity.user_id = v_target_id
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
      where user_badge.user_id = v_target_id
    ), '[]'::jsonb)
  )
  into v_result
  from app.user_profiles profile
  left join competition.user_progress progress on progress.user_id = profile.user_id
  left join competition.level_definitions level on level.level_number = progress.current_level
  where profile.user_id = v_target_id;

  return v_result;
end;
$$;

-- Bell badge support: unread count and a bulk "seen" action.
create or replace function api.get_current_user_unread_notification_count()
returns integer
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

  return (
    select count(*)::integer
    from app.notifications notification
    where notification.user_id = v_user_id and notification.read_at is null
  );
end;
$$;

create or replace function api.mark_all_current_user_notifications_read()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  update app.notifications
  set read_at = now()
  where user_id = v_user_id and read_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function api.get_current_user_friend_invite() from public, anon;
revoke all on function api.get_friend_invite_preview(text) from public, anon;
revoke all on function api.accept_friend_invite(text) from public, anon;
revoke all on function api.get_user_public_profile(text) from public, anon;
revoke all on function api.get_current_user_unread_notification_count() from public, anon;
revoke all on function api.mark_all_current_user_notifications_read() from public, anon;

grant execute on function api.get_current_user_friend_invite() to authenticated, service_role;
grant execute on function api.get_friend_invite_preview(text) to authenticated, service_role;
grant execute on function api.accept_friend_invite(text) to authenticated, service_role;
grant execute on function api.get_user_public_profile(text) to authenticated, service_role;
grant execute on function api.get_current_user_unread_notification_count() to authenticated, service_role;
grant execute on function api.mark_all_current_user_notifications_read() to authenticated, service_role;
