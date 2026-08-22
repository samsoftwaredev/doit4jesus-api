-- Profile identity fields used by the authenticated-profile API. Gender is
-- required and intentionally restricted to the existing legacy values.

alter table app.user_profiles
  add column if not exists gender text,
  add column if not exists saint_avatar_id uuid;

-- Preserve known values from the legacy profile table before enforcing the new
-- invariant. Do not infer a gender for a profile whose legacy value is absent
-- or invalid.
do $$
begin
  if to_regclass('public.profiles') is not null then
    execute $backfill$
      update app.user_profiles profile
      set gender = lower(trim(legacy.gender))
      from public.profiles legacy
      where profile.user_id = legacy.id
        and profile.gender is null
        and lower(trim(legacy.gender)) in ('male', 'female')
    $backfill$;
  end if;
end
$$;

-- Some accounts may have supplied gender during Supabase sign-up without a
-- matching legacy profile row. Use it only when it is one of the supported
-- values.
update app.user_profiles profile
set gender = lower(trim(auth_user.raw_user_meta_data ->> 'gender'))
from auth.users auth_user
where profile.user_id = auth_user.id
  and profile.gender is null
  and lower(trim(auth_user.raw_user_meta_data ->> 'gender')) in ('male', 'female');

do $$
declare
  missing_profile_count integer;
begin
  select count(*)
  into missing_profile_count
  from app.user_profiles
  where gender is null;

  if missing_profile_count > 0 then
    raise exception 'PROFILE_GENDER_BACKFILL_REQUIRED: % profile(s) need gender before this migration can be applied.', missing_profile_count;
  end if;
end
$$;

alter table app.user_profiles
  alter column gender set not null,
  add constraint user_profiles_gender_check check (gender in ('male', 'female')),
  add constraint user_profiles_saint_avatar_id_fkey
    foreign key (saint_avatar_id)
    references competition.saint_definitions(id)
    on delete set null;
