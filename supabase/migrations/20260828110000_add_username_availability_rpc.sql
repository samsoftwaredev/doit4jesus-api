-- Case-insensitive username availability checks for validation and generated
-- suggestions. The RPC exposes only a boolean and excludes the current user's
-- existing username so profile edits remain idempotent.

create or replace function api.check_username_availability(
  p_usernames text[]
)
returns table (
  username text,
  is_available boolean
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

  if p_usernames is null
    or cardinality(p_usernames) < 1
    or cardinality(p_usernames) > 100
    or exists (
      select 1
      from unnest(p_usernames) as candidate(value)
      where candidate.value is null
        or char_length(trim(candidate.value)) < 1
        or char_length(trim(candidate.value)) > 30
    ) then
    raise exception 'INVALID_USERNAME_CANDIDATES' using errcode = 'P0001';
  end if;

  return query
  select
    trim(candidate.value) as username,
    not exists (
      select 1
      from app.user_profiles profile
      where lower(profile.username) = lower(trim(candidate.value))
        and profile.user_id <> v_user_id
    ) as is_available
  from unnest(p_usernames) with ordinality as candidate(value, position)
  order by candidate.position;
end;
$$;

revoke all on function api.check_username_availability(text[])
from public, anon;

grant execute on function api.check_username_availability(text[])
to authenticated, service_role;
