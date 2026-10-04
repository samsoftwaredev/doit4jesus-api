-- Decouple reminder preferences from profile onboarding. Existing preference
-- rows are intentionally preserved; first-time rows use disabled defaults.

alter table app.notification_preferences
  alter column daily_rosary_reminder set default false,
  alter column confession_reminder set default false,
  alter column eucharistic_adoration set default false;

drop function if exists api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text,
  boolean,
  boolean,
  boolean
);

create function api.complete_current_user_profile_setup(
  p_display_name text,
  p_username text,
  p_gender text,
  p_country_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_display_name text := pg_catalog.regexp_replace(
    pg_catalog.btrim(p_display_name),
    '\\s+',
    ' ',
    'g'
  );
  v_country_code text := pg_catalog.upper(pg_catalog.btrim(p_country_code));
  v_completed_at timestamptz := now();
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if v_display_name is null
    or pg_catalog.char_length(v_display_name) < 1
    or pg_catalog.char_length(v_display_name) > 80
    or p_gender is null
    or p_gender not in ('male', 'female')
    or v_country_code is null
    or v_country_code !~ '^[A-Z]{2}$'
    or (
      p_username is not null
      and (
        pg_catalog.char_length(pg_catalog.btrim(p_username)) < 3
        or pg_catalog.char_length(pg_catalog.btrim(p_username)) > 30
        or pg_catalog.btrim(p_username) !~ '^[A-Za-z0-9_]+$'
      )
    ) then
    raise exception 'INVALID_PROFILE_SETUP' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from app.countries country
    where country.code = v_country_code::char(2)
      and country.is_active
  ) then
    raise exception 'PROFILE_COUNTRY_NOT_FOUND' using errcode = 'P0001';
  end if;

  update app.user_profiles profile
  set
    display_name = v_display_name,
    username = nullif(pg_catalog.btrim(p_username), ''),
    gender = p_gender,
    country_code = v_country_code::char(2),
    profile_setup_completed_at = v_completed_at
  where profile.user_id = v_user_id;

  if not found then
    raise exception 'USER_PROFILE_NOT_FOUND' using errcode = 'P0001';
  end if;

  insert into app.notification_preferences (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  return jsonb_build_object('completedAt', v_completed_at);
end;
$$;

revoke all on function api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text
) from public, anon, authenticated;

grant execute on function api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text
) to authenticated, service_role;
