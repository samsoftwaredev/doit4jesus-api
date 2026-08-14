-- Username discovery intentionally exposes only the profile fields needed to
-- identify a user and send a friend request. It does not inherit leaderboard
-- visibility because user discovery is a separate product decision.

create extension if not exists pg_trgm with schema extensions;

create index if not exists user_profiles_username_search_trgm
on app.user_profiles
using gin (lower(username::text) extensions.gin_trgm_ops)
where username is not null;

create or replace function api.search_users(
  p_query text,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  username varchar,
  avatar_url text,
  title varchar,
  relationship_state text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := lower(trim(p_query));
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  -- Validate here as well as in the route because this RPC is callable through
  -- the Supabase API. The minimum prevents broad username enumeration.
  if v_query !~ '^[a-z0-9_]{4,30}$' then
    raise exception 'INVALID_USER_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  return query
  with matched_profiles as (
    select
      profile.user_id,
      profile.username::varchar as username,
      profile.avatar_url,
      profile.title,
      case
        when lower(profile.username::text) = v_query then 0
        when strpos(lower(profile.username::text), v_query) = 1 then 1
        else 2
      end as match_rank
    from app.user_profiles profile
    join app.users user_record
      on user_record.id = profile.user_id
      and user_record.status = 'active'
      and user_record.deleted_at is null
    where profile.user_id <> v_user_id
      and profile.username is not null
      -- The query permits underscores, which must be escaped so they match
      -- literally instead of acting as a SQL LIKE wildcard.
      and lower(profile.username::text) like
        '%' || replace(v_query, '_', chr(92) || '_') || '%'
        escape chr(92)
  )
  select
    profile.username,
    profile.avatar_url,
    profile.title,
    case
      when exists (
        select 1
        from app.friendships friendship
        where friendship.user_low_id = least(v_user_id, profile.user_id)
          and friendship.user_high_id = greatest(v_user_id, profile.user_id)
      ) then 'friends'
      when exists (
        select 1
        from app.friend_requests request_record
        where request_record.requester_id = v_user_id
          and request_record.recipient_id = profile.user_id
          and request_record.status = 'pending'
      ) then 'outgoingPending'
      when exists (
        select 1
        from app.friend_requests request_record
        where request_record.requester_id = profile.user_id
          and request_record.recipient_id = v_user_id
          and request_record.status = 'pending'
      ) then 'incomingPending'
      else 'none'
    end as relationship_state
  from matched_profiles profile
  order by profile.match_rank, lower(profile.username::text), profile.user_id
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function api.search_users(text, integer, integer)
from public, anon;

grant execute on function api.search_users(text, integer, integer)
to authenticated, service_role;
