-- Serialize request creation per unordered user pair. Without this lock, two
-- simultaneous reciprocal sends could both insert before observing the other.

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

  perform pg_advisory_xact_lock(
    hashtext(least(v_requester_id, v_recipient_id)::text),
    hashtext(greatest(v_requester_id, v_recipient_id)::text)
  );

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
