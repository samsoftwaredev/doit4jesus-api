-- Required profile onboarding. Completeness is derived from the canonical
-- profile values; profile_setup_completed_at is audit metadata only.

alter table app.users
  alter column email drop not null;

alter table app.user_profiles
  alter column display_name drop not null,
  alter column gender drop not null,
  add column if not exists profile_setup_completed_at timestamptz;

create table app.notification_preferences (
  user_id uuid primary key references app.users(id) on delete cascade,
  daily_rosary_reminder boolean not null default true,
  confession_reminder boolean not null default true,
  eucharistic_adoration boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_notification_preferences_updated_at
before update on app.notification_preferences
for each row execute function platform.set_updated_at();

alter table app.notification_preferences enable row level security;

grant select on app.notification_preferences to authenticated;
grant insert (
  user_id,
  daily_rosary_reminder,
  confession_reminder,
  eucharistic_adoration
) on app.notification_preferences to authenticated;
grant update (
  daily_rosary_reminder,
  confession_reminder,
  eucharistic_adoration
) on app.notification_preferences to authenticated;
grant all privileges on app.notification_preferences to service_role;

-- These columns were added after the original column-level profile grant.
grant update (gender, saint_avatar_id) on app.user_profiles to authenticated;

create policy notification_preferences_select_own
on app.notification_preferences
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy notification_preferences_insert_own
on app.notification_preferences
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy notification_preferences_update_own
on app.notification_preferences
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create or replace function app.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display_name text := nullif(
    regexp_replace(
      btrim(
        coalesce(
          new.raw_user_meta_data ->> 'display_name',
          new.raw_user_meta_data ->> 'full_name',
          new.raw_user_meta_data ->> 'name',
          ''
        )
      ),
      '\s+',
      ' ',
      'g'
    ),
    ''
  );
  v_gender text := case
    when lower(btrim(new.raw_user_meta_data ->> 'gender')) in ('male', 'female')
      then lower(btrim(new.raw_user_meta_data ->> 'gender'))
    else null
  end;
begin
  insert into app.users (
    id,
    email,
    status,
    email_verified_at,
    created_at,
    updated_at
  )
  values (
    new.id,
    new.email,
    'active',
    new.email_confirmed_at,
    coalesce(new.created_at, now()),
    now()
  )
  on conflict (id) do update
  set
    email = excluded.email,
    email_verified_at = excluded.email_verified_at,
    updated_at = now();

  insert into app.user_profiles (user_id, display_name, gender)
  values (new.id, v_display_name, v_gender)
  on conflict (user_id) do nothing;

  insert into app.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function app.handle_auth_user_created()
from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function app.handle_auth_user_created();

-- Bring databases created before the bootstrap trigger into the same state.
insert into app.users (
  id,
  email,
  status,
  email_verified_at,
  created_at,
  updated_at
)
select
  auth_user.id,
  auth_user.email,
  'active',
  auth_user.email_confirmed_at,
  coalesce(auth_user.created_at, now()),
  now()
from auth.users auth_user
on conflict (id) do nothing;

insert into app.user_profiles (user_id, display_name, gender)
select
  user_record.id,
  nullif(
    regexp_replace(
      btrim(
        coalesce(
          auth_user.raw_user_meta_data ->> 'display_name',
          auth_user.raw_user_meta_data ->> 'full_name',
          auth_user.raw_user_meta_data ->> 'name',
          ''
        )
      ),
      '\s+',
      ' ',
      'g'
    ),
    ''
  ),
  case
    when lower(btrim(auth_user.raw_user_meta_data ->> 'gender')) in ('male', 'female')
      then lower(btrim(auth_user.raw_user_meta_data ->> 'gender'))
    else null
  end
from app.users user_record
join auth.users auth_user on auth_user.id = user_record.id
on conflict (user_id) do nothing;

insert into app.notification_preferences (user_id)
select profile.user_id
from app.user_profiles profile
on conflict (user_id) do nothing;

update app.user_profiles profile
set profile_setup_completed_at = profile.updated_at
where profile.profile_setup_completed_at is null
  and nullif(btrim(profile.display_name), '') is not null
  and profile.gender in ('male', 'female')
  and profile.country_code is not null
  and profile.city_id is not null;

create or replace function api.complete_current_user_profile_setup(
  p_display_name text,
  p_username text,
  p_gender text,
  p_country_code text,
  p_city_id uuid,
  p_daily_rosary_reminder boolean,
  p_confession_reminder boolean,
  p_eucharistic_adoration boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_display_name text := regexp_replace(btrim(p_display_name), '\s+', ' ', 'g');
  v_country_code text := upper(btrim(p_country_code));
  v_city_country_code text;
  v_completed_at timestamptz := now();
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if v_display_name is null
    or char_length(v_display_name) < 1
    or char_length(v_display_name) > 80
    or p_gender is null
    or p_gender not in ('male', 'female')
    or v_country_code is null
    or v_country_code !~ '^[A-Z]{2}$'
    or p_city_id is null
    or p_daily_rosary_reminder is null
    or p_confession_reminder is null
    or p_eucharistic_adoration is null
    or (
      p_username is not null
      and (
        char_length(btrim(p_username)) < 3
        or char_length(btrim(p_username)) > 30
        or btrim(p_username) !~ '^[A-Za-z0-9_]+$'
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

  select city.country_code::text
  into v_city_country_code
  from app.cities city
  where city.id = p_city_id
    and city.is_active;

  if v_city_country_code is null then
    raise exception 'PROFILE_CITY_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_city_country_code <> v_country_code then
    raise exception 'PROFILE_CITY_COUNTRY_MISMATCH' using errcode = 'P0001';
  end if;

  update app.user_profiles profile
  set
    display_name = v_display_name,
    username = nullif(btrim(p_username), ''),
    gender = p_gender,
    country_code = v_country_code::char(2),
    city_id = p_city_id,
    profile_setup_completed_at = v_completed_at
  where profile.user_id = v_user_id;

  if not found then
    raise exception 'USER_PROFILE_NOT_FOUND' using errcode = 'P0001';
  end if;

  insert into app.notification_preferences (
    user_id,
    daily_rosary_reminder,
    confession_reminder,
    eucharistic_adoration
  )
  values (
    v_user_id,
    p_daily_rosary_reminder,
    p_confession_reminder,
    p_eucharistic_adoration
  )
  on conflict (user_id) do update
  set
    daily_rosary_reminder = excluded.daily_rosary_reminder,
    confession_reminder = excluded.confession_reminder,
    eucharistic_adoration = excluded.eucharistic_adoration;

  return jsonb_build_object('completedAt', v_completed_at);
end;
$$;

revoke all on function api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text,
  uuid,
  boolean,
  boolean,
  boolean
)
from public, anon;

grant execute on function api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text,
  uuid,
  boolean,
  boolean,
  boolean
)
to authenticated, service_role;
