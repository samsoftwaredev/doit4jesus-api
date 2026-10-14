-- PostgreSQL does not implicitly widen varchar profile columns when returning
-- a table declared with text fields. Cast both display fields explicitly.

create or replace function api.search_admin_users(
  p_query text,
  p_limit integer default 20
)
returns table (
  id uuid,
  email text,
  status text,
  created_at timestamptz,
  display_name text,
  username text,
  is_admin boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := lower(trim(coalesce(p_query, '')));
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if char_length(v_query) < 2 or char_length(v_query) > 320 then
    raise exception 'INVALID_ADMIN_USER_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  return query
  select
    user_record.id,
    user_record.email::text,
    user_record.status,
    user_record.created_at,
    profile.display_name::text,
    profile.username::text,
    exists (
      select 1 from app.user_roles role_record
      where role_record.user_id = user_record.id and role_record.role = 'admin'
    )
  from app.users user_record
  left join app.user_profiles profile on profile.user_id = user_record.id
  where (
    (v_query ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and user_record.id = v_query::uuid)
    or (
      v_query !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and position(v_query in lower(coalesce(user_record.email::text, ''))) > 0
    )
  )
  order by user_record.created_at desc, user_record.id
  limit greatest(1, least(coalesce(p_limit, 20), 20));
end;
$$;

revoke all on function api.search_admin_users(text, integer) from public, anon;
grant execute on function api.search_admin_users(text, integer)
to authenticated, service_role;

notify pgrst, 'reload schema';
