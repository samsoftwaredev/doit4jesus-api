-- A user's profile country is deliberately visible in the social features.
-- Keep the country lookup private to security-definer functions so direct table
-- access remains governed by app.user_profiles RLS.

create or replace function app.profile_country_code_jsonb(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select to_jsonb(profile.country_code)
      from app.user_profiles profile
      where profile.user_id = p_user_id
    ),
    'null'::jsonb
  );
$$;

revoke all on function app.profile_country_code_jsonb(uuid)
  from public, anon, authenticated, service_role;

-- The global leaderboard already uses this projection to prevent profile
-- details from leaking. Country is now an intentional part of that projection.
create or replace view app.leaderboard_profiles
with (security_barrier = true)
as
select
  user_id,
  (
    case
      when leaderboard_visibility = 'public' or user_id = (select auth.uid())
        then display_name
      else 'Private Player'
    end
  )::varchar(80) as display_name,
  (
    case
      when leaderboard_visibility = 'public' or user_id = (select auth.uid())
        then username
      else null
    end
  )::public.citext as username,
  case
    when leaderboard_visibility = 'public' or user_id = (select auth.uid())
      then avatar_url
    else null
  end as avatar_url,
  (
    case
      when leaderboard_visibility = 'public' or user_id = (select auth.uid())
        then title
      else null
    end
  )::varchar(100) as title,
  country_code
from app.user_profiles;

alter function api.list_current_user_friend_requests(text, text, integer, integer)
  rename to list_current_user_friend_requests_base;
revoke all on function api.list_current_user_friend_requests_base(text, text, integer, integer)
  from public, anon, authenticated, service_role;

create function api.list_current_user_friend_requests(
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
  title varchar,
  country_code varchar
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return query
  select
    request_record.id,
    request_record.status,
    request_record.direction,
    request_record.created_at,
    request_record.responded_at,
    request_record.cancelled_at,
    request_record.user_id,
    request_record.display_name,
    request_record.username,
    request_record.avatar_url,
    request_record.title,
    profile.country_code::varchar
  from api.list_current_user_friend_requests_base(
    p_direction,
    p_status,
    p_limit,
    p_offset
  ) request_record
  join app.user_profiles profile on profile.user_id = request_record.user_id;
end;
$$;

revoke all on function api.list_current_user_friend_requests(text, text, integer, integer)
  from public, anon;
grant execute on function api.list_current_user_friend_requests(text, text, integer, integer)
  to authenticated, service_role;

alter function api.list_current_user_friends(integer, integer, boolean)
  rename to list_current_user_friends_base;
revoke all on function api.list_current_user_friends_base(integer, integer, boolean)
  from public, anon, authenticated, service_role;

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
  rosary_streak jsonb,
  country_code varchar
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return query
  select
    friend.friend_id,
    friend.display_name,
    friend.username,
    friend.avatar_url,
    friend.title,
    friend.total_xp,
    friend.current_level,
    friend.level_code,
    friend.level_name,
    friend.rosary_total,
    friend.badge_count,
    friend.friends_since,
    friend.rosary_streak,
    profile.country_code::varchar
  from api.list_current_user_friends_base(
    p_limit,
    p_offset,
    p_include_rosary_streak
  ) friend
  join app.user_profiles profile on profile.user_id = friend.friend_id;
end;
$$;

revoke all on function api.list_current_user_friends(integer, integer, boolean)
  from public, anon;
grant execute on function api.list_current_user_friends(integer, integer, boolean)
  to authenticated, service_role;

alter function api.get_current_user_friend_details(uuid, boolean)
  rename to get_current_user_friend_details_base;
revoke all on function api.get_current_user_friend_details_base(uuid, boolean)
  from public, anon, authenticated, service_role;

create function api.get_current_user_friend_details(
  p_friend_id uuid,
  p_include_rosary_streak boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  v_result := api.get_current_user_friend_details_base(
    p_friend_id,
    p_include_rosary_streak
  );

  return jsonb_set(
    v_result,
    '{friend,countryCode}',
    app.profile_country_code_jsonb(p_friend_id),
    true
  );
end;
$$;

revoke all on function api.get_current_user_friend_details(uuid, boolean)
  from public, anon;
grant execute on function api.get_current_user_friend_details(uuid, boolean)
  to authenticated, service_role;

alter function api.get_current_user_friends_leaderboard(text, text, integer, integer)
  rename to get_current_user_friends_leaderboard_base;
revoke all on function api.get_current_user_friends_leaderboard_base(text, text, integer, integer)
  from public, anon, authenticated, service_role;

create function api.get_current_user_friends_leaderboard(
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
  v_result jsonb;
  v_entries jsonb;
  v_current_user_entry jsonb;
begin
  v_result := api.get_current_user_friends_leaderboard_base(
    p_period_type,
    p_period_code,
    p_limit,
    p_offset
  );

  select coalesce(
    jsonb_agg(
      jsonb_set(
        entry,
        '{friend,countryCode}',
        app.profile_country_code_jsonb((entry #>> '{friend,id}')::uuid),
        true
      )
    ),
    '[]'::jsonb
  )
  into v_entries
  from jsonb_array_elements(coalesce(v_result -> 'entries', '[]'::jsonb)) entry;

  v_current_user_entry := v_result -> 'currentUserEntry';
  if v_current_user_entry is not null
    and v_current_user_entry <> 'null'::jsonb then
    v_current_user_entry := jsonb_set(
      v_current_user_entry,
      '{friend,countryCode}',
      app.profile_country_code_jsonb(
        (v_current_user_entry #>> '{friend,id}')::uuid
      ),
      true
    );
  else
    v_current_user_entry := 'null'::jsonb;
  end if;

  return jsonb_build_object(
    'period', v_result -> 'period',
    'entries', v_entries,
    'currentUserEntry', v_current_user_entry,
    'total', v_result -> 'total'
  );
end;
$$;

revoke all on function api.get_current_user_friends_leaderboard(text, text, integer, integer)
  from public, anon;
grant execute on function api.get_current_user_friends_leaderboard(text, text, integer, integer)
  to authenticated, service_role;

alter function api.get_current_user_friends_comparison(text, text, integer, integer)
  rename to get_current_user_friends_comparison_base;
revoke all on function api.get_current_user_friends_comparison_base(text, text, integer, integer)
  from public, anon, authenticated, service_role;

create function api.get_current_user_friends_comparison(
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
  v_result jsonb;
  v_entries jsonb;
begin
  v_result := api.get_current_user_friends_comparison_base(
    p_period_type,
    p_period_code,
    p_limit,
    p_offset
  );

  select coalesce(
    jsonb_agg(
      jsonb_set(
        entry,
        '{profile,countryCode}',
        app.profile_country_code_jsonb((entry #>> '{profile,id}')::uuid),
        true
      )
    ),
    '[]'::jsonb
  )
  into v_entries
  from jsonb_array_elements(coalesce(v_result -> 'entries', '[]'::jsonb)) entry;

  return jsonb_set(v_result, '{entries}', v_entries, true);
end;
$$;

revoke all on function api.get_current_user_friends_comparison(text, text, integer, integer)
  from public, anon;
grant execute on function api.get_current_user_friends_comparison(text, text, integer, integer)
  to authenticated, service_role;
