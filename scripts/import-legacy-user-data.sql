\set ECHO errors
\pset pager off

begin;

set local lock_timeout = '10s';
set local statement_timeout = '10min';

create temporary table legacy_profiles (
  id uuid primary key,
  updated_at timestamptz,
  username text,
  picture_url text,
  gender text,
  birth_date date,
  first_name text,
  last_name text,
  invited_by uuid,
  created_at timestamptz not null,
  rosary_count bigint not null,
  rosary_streak bigint not null,
  language text,
  role text not null,
  city text,
  state text,
  last_seen timestamptz
) on commit drop;

create temporary table legacy_user_xp (
  id uuid primary key,
  user_id uuid not null unique,
  total_xp bigint not null,
  current_level integer not null,
  current_title text not null,
  updated_at timestamptz not null,
  created_at timestamptz not null
) on commit drop;

create temporary table legacy_rosary_stats (
  user_id uuid not null,
  completed_at date not null,
  id uuid primary key,
  join_rosary_user_id uuid,
  created_at timestamptz
) on commit drop;

create temporary table legacy_profile_identity_rules (
  id uuid primary key,
  generated_username text not null unique,
  generation_strategy text not null check (
    generation_strategy in ('name', 'safe_fallback')
  )
) on commit drop;

\copy pg_temp.legacy_profiles from __PROFILES_CSV__ with (format csv, header true)
\copy pg_temp.legacy_user_xp from __USER_XP_CSV__ with (format csv, header true)
\copy pg_temp.legacy_rosary_stats from __ROSARY_STATS_CSV__ with (format csv, header true)
\copy pg_temp.legacy_profile_identity_rules from __PROFILE_IDENTITIES_CSV__ with (format csv, header true)

create index legacy_rosary_stats_user_id_idx
  on legacy_rosary_stats (user_id);

do $$
begin
  if (select count(*) from legacy_profiles) <> 533 then
    raise exception 'LEGACY_IMPORT_INVALID_PROFILE_COUNT';
  end if;

  if (select count(*) from legacy_user_xp) <> 15 then
    raise exception 'LEGACY_IMPORT_INVALID_XP_COUNT';
  end if;

  if (select count(*) from legacy_rosary_stats) <> 1625 then
    raise exception 'LEGACY_IMPORT_INVALID_ROSARY_COUNT';
  end if;

  if (select count(*) from legacy_profile_identity_rules) <> 533
    or exists (
      select 1
      from legacy_profiles profile
      full join legacy_profile_identity_rules identity_rule
        on identity_rule.id = profile.id
      where profile.id is null or identity_rule.id is null
    )
  then
    raise exception 'LEGACY_IMPORT_INVALID_PROFILE_IDENTITY_RULES';
  end if;

  if exists (
    select 1
    from legacy_profile_identity_rules identity_rule
    where identity_rule.generated_username !~ '^[A-Za-z0-9_]{3,30}$'
  ) then
    raise exception 'LEGACY_IMPORT_GENERATED_USERNAME_INVALID';
  end if;

  if exists (
    select 1
    from legacy_user_xp xp
    left join legacy_profiles profile on profile.id = xp.user_id
    where profile.id is null
  ) then
    raise exception 'LEGACY_IMPORT_XP_PROFILE_MISSING';
  end if;

  if exists (
    select 1
    from legacy_rosary_stats rosary
    left join legacy_profiles profile on profile.id = rosary.user_id
    where profile.id is null
  ) then
    raise exception 'LEGACY_IMPORT_ROSARY_PROFILE_MISSING';
  end if;

  if exists (
    select 1
    from legacy_rosary_stats rosary
    left join legacy_profiles profile on profile.id = rosary.join_rosary_user_id
    where rosary.join_rosary_user_id is not null
      and profile.id is null
  ) then
    raise exception 'LEGACY_IMPORT_JOINED_PROFILE_MISSING';
  end if;

  if exists (
    select 1
    from legacy_profiles profile
    left join (
      select rosary.user_id, count(*)::bigint as rosary_count
      from legacy_rosary_stats rosary
      group by rosary.user_id
    ) totals on totals.user_id = profile.id
    where profile.rosary_count <> coalesce(totals.rosary_count, 0)
  ) then
    raise exception 'LEGACY_IMPORT_ROSARY_TOTAL_MISMATCH';
  end if;

  if exists (
    select lower(btrim(profile.username))
    from legacy_profiles profile
    where profile.username is not null
      and btrim(profile.username) ~ '^[A-Za-z0-9_]{3,30}$'
    group by lower(btrim(profile.username))
    having count(*) > 1
  ) then
    raise exception 'LEGACY_IMPORT_DUPLICATE_VALID_USERNAME';
  end if;

  if exists (
    select 1
    from legacy_profiles profile
    where profile.rosary_count < 0
      or profile.rosary_streak < 0
  ) then
    raise exception 'LEGACY_IMPORT_NEGATIVE_PROFILE_TOTAL';
  end if;

  if exists (
    select 1
    from legacy_profiles profile
    where char_length(nullif(pg_catalog.regexp_replace(
      btrim(concat_ws(' ', profile.first_name, profile.last_name)),
      '\s+',
      ' ',
      'g'
    ), '')) > 80
  ) then
    raise exception 'LEGACY_IMPORT_DISPLAY_NAME_TOO_LONG';
  end if;

  if exists (
    select 1
    from legacy_user_xp xp
    where xp.total_xp < 0
      or xp.total_xp > 2147483647
      or char_length(btrim(xp.current_title)) > 100
  ) then
    raise exception 'LEGACY_IMPORT_INVALID_XP_TOTAL';
  end if;
end
$$;

\if :verify

create temporary table legacy_verification_mapping on commit drop as
select
  source_user.user_id as source_user_id,
  target_user.id as target_user_id
from (
  select xp.user_id
  from legacy_user_xp xp
  join legacy_profiles profile on profile.id = xp.user_id
  where profile.rosary_count > 0
  order by
    (
      nullif(btrim(profile.username), '') is null
      and (profile.gender is null or lower(btrim(profile.gender)) not in ('male', 'female'))
    ) desc,
    xp.total_xp desc,
    xp.user_id
  limit 1
) source_user
cross join lateral (
  select auth_user.id
  from auth.users auth_user
  where not exists (
    select 1 from legacy_profiles profile where profile.id = auth_user.id
  )
  order by auth_user.created_at, auth_user.id
  limit 1
) target_user;

do $$
begin
  if (select count(*) from legacy_verification_mapping) <> 1 then
    raise exception 'LEGACY_IMPORT_LOCAL_VERIFICATION_USER_MISSING';
  end if;
end
$$;

update legacy_rosary_stats rosary
set join_rosary_user_id = mapping.target_user_id
from legacy_verification_mapping mapping
where rosary.join_rosary_user_id = mapping.source_user_id;

update legacy_rosary_stats rosary
set user_id = mapping.target_user_id
from legacy_verification_mapping mapping
where rosary.user_id = mapping.source_user_id;

update legacy_user_xp xp
set user_id = mapping.target_user_id
from legacy_verification_mapping mapping
where xp.user_id = mapping.source_user_id;

update legacy_profiles profile
set id = mapping.target_user_id
from legacy_verification_mapping mapping
where profile.id = mapping.source_user_id;

update legacy_profile_identity_rules identity_rule
set id = mapping.target_user_id
from legacy_verification_mapping mapping
where identity_rule.id = mapping.source_user_id;

\endif

create temporary table legacy_matched_users on commit drop as
select profile.*
from legacy_profiles profile
join auth.users auth_user on auth_user.id = profile.id;

alter table legacy_matched_users add primary key (id);

\if :verify

-- Exercise generated usernames and incomplete onboarding during the local
-- rollback-only integration check. The selected legacy account has neither a
-- usable username nor a known gender.
select profile.user_id
from app.user_profiles profile
join legacy_matched_users matched on matched.id = profile.user_id
for update of profile;

update app.user_profiles profile
set
  username = null,
  gender = null,
  profile_setup_completed_at = null
from legacy_matched_users matched
where profile.user_id = matched.id;

\endif

create temporary table legacy_profile_candidates on commit drop as
with normalized as (
  select
    matched.id,
    nullif(pg_catalog.regexp_replace(
      btrim(concat_ws(' ', matched.first_name, matched.last_name)),
      '\s+',
      ' ',
      'g'
    ), '') as display_name,
    case
      when btrim(matched.username) ~ '^[A-Za-z0-9_]{3,30}$'
        then btrim(matched.username)
    end as valid_legacy_username,
    identity_rule.generated_username,
    identity_rule.generation_strategy,
    nullif(btrim(current_profile.username::text), '') as current_username,
    case when matched.picture_url ~ '^https://' then btrim(matched.picture_url) end as avatar_url,
    nullif(btrim(xp.current_title), '') as title,
    case
      when lower(btrim(matched.gender)) in ('male', 'female')
        then lower(btrim(matched.gender))
    end as legacy_gender,
    current_profile.gender as current_gender,
    case
      when char_length(btrim(matched.language)) between 2 and 10
        then btrim(matched.language)
    end as preferred_language,
    case when lower(btrim(matched.state)) = 'united states' then 'US'::char(2) end as country_code
  from legacy_matched_users matched
  join legacy_profile_identity_rules identity_rule on identity_rule.id = matched.id
  left join legacy_user_xp xp on xp.user_id = matched.id
  left join app.user_profiles current_profile on current_profile.user_id = matched.id
), resolved as (
  select
    normalized.*,
    case
      when normalized.valid_legacy_username is not null
        and not exists (
          select 1
          from app.user_profiles other_profile
          where other_profile.user_id <> normalized.id
            and other_profile.username = normalized.valid_legacy_username
        ) then normalized.valid_legacy_username
      else normalized.generated_username
    end as username_candidate,
    case
      when normalized.current_username is not null then 'existing'
      when normalized.valid_legacy_username is not null
        and not exists (
          select 1
          from app.user_profiles other_profile
          where other_profile.user_id <> normalized.id
            and other_profile.username = normalized.valid_legacy_username
        ) then 'legacy'
      else 'generated_' || normalized.generation_strategy
    end as username_source
  from normalized
)
select * from resolved;

alter table legacy_profile_candidates add primary key (id);

create temporary table legacy_first_rosary_badge on commit drop as
select
  badge.id as badge_id,
  requirement.id as requirement_id,
  requirement.required_value
from competition.badge_definitions badge
join competition.badge_requirement_definitions requirement
  on requirement.badge_id = badge.id
join competition.badge_requirement_activity_rules activity_rule
  on activity_rule.badge_requirement_id = requirement.id
where badge.code = 'FIRST_ROSARY'
  and requirement.required_value = 1
  and activity_rule.activity_code = 'ROSARY'
  and activity_rule.progress_mode = 'activity_quantity'
  and activity_rule.metadata_filter = '{}'::jsonb;

do $$
begin
  if (select count(*) from legacy_first_rosary_badge) <> 1 then
    raise exception 'LEGACY_IMPORT_FIRST_ROSARY_RULE_CHANGED';
  end if;

  if exists (
    select 1
    from competition.badge_requirement_activity_rules activity_rule
    join competition.badge_requirement_definitions requirement
      on requirement.id = activity_rule.badge_requirement_id
    join competition.badge_definitions badge on badge.id = requirement.badge_id
    where activity_rule.activity_code = 'ROSARY'
      and badge.code <> 'FIRST_ROSARY'
  ) then
    raise exception 'LEGACY_IMPORT_UNSUPPORTED_ROSARY_BADGE_RULE';
  end if;

  if position(
    'legacy_balance' in pg_get_functiondef(
      'competition.refresh_leaderboard_period(uuid)'::regprocedure
    )
  ) = 0 then
    raise exception 'LEGACY_IMPORT_LEADERBOARD_MIGRATION_REQUIRED';
  end if;

  if exists (
    select 1
    from legacy_matched_users legacy
    join auth.users auth_user on auth_user.id = legacy.id
    left join app.users own_user on own_user.id = legacy.id
    join app.users conflicting_user
      on conflicting_user.email = auth_user.email
      and conflicting_user.id <> auth_user.id
    where auth_user.email is not null
      and own_user.email is null
  ) then
    raise exception 'LEGACY_IMPORT_APP_USER_EMAIL_CONFLICT';
  end if;

  if not exists (
    select 1
    from app.countries country
    where country.code = 'US'::char(2)
      and country.is_active
  ) then
    raise exception 'LEGACY_IMPORT_US_COUNTRY_MISSING';
  end if;

  if exists (
    select 1
    from legacy_profile_candidates candidate
    where candidate.current_username is null
      and candidate.username_candidate !~ '^[A-Za-z0-9_]{3,30}$'
  ) then
    raise exception 'LEGACY_IMPORT_GENERATED_USERNAME_INVALID';
  end if;

  if exists (
    select lower(candidate.username_candidate)
    from legacy_profile_candidates candidate
    where candidate.current_username is null
    group by lower(candidate.username_candidate)
    having count(*) > 1
  ) then
    raise exception 'LEGACY_IMPORT_GENERATED_USERNAME_DUPLICATE';
  end if;

  if exists (
    select 1
    from legacy_profile_candidates candidate
    join app.user_profiles other_profile
      on other_profile.username = candidate.username_candidate
      and other_profile.user_id <> candidate.id
    where candidate.current_username is null
  ) then
    raise exception 'LEGACY_IMPORT_GENERATED_USERNAME_CONFLICT';
  end if;

  if exists (
    select 1
    from legacy_rosary_stats legacy_rosary
    join legacy_matched_users matched on matched.id = legacy_rosary.user_id
    join competition.spiritual_activities activity on activity.id = legacy_rosary.id
    where activity.activity_code <> 'ROSARY'
      or not exists (
        select 1 from legacy_matched_users owner where owner.id = activity.user_id
      )
  ) then
    raise exception 'LEGACY_IMPORT_ACTIVITY_ID_CONFLICT';
  end if;

  if exists (
    select 1
    from legacy_user_xp legacy_xp
    join legacy_matched_users matched on matched.id = legacy_xp.user_id
    join competition.point_ledger ledger on ledger.id = legacy_xp.id
    where not exists (
      select 1 from legacy_matched_users owner where owner.id = ledger.user_id
    )
  ) then
    raise exception 'LEGACY_IMPORT_LEDGER_ID_CONFLICT';
  end if;

  if exists (
    select 1
    from legacy_user_xp legacy_xp
    join legacy_matched_users matched on matched.id = legacy_xp.user_id
    join competition.point_ledger ledger
      on ledger.idempotency_key = 'legacy-user-xp:' || legacy_xp.id::text
    where not exists (
      select 1 from legacy_matched_users owner where owner.id = ledger.user_id
    )
  ) then
    raise exception 'LEGACY_IMPORT_LEDGER_IDEMPOTENCY_CONFLICT';
  end if;

  if exists (
    select 1
    from prayer.daily_scripture_completions completion
    join competition.spiritual_activities activity
      on activity.id = completion.activity_id
    join legacy_matched_users matched on matched.id = activity.user_id
    where activity.activity_code = 'ROSARY'
  ) then
    raise exception 'LEGACY_IMPORT_ROSARY_REFERENCED_AS_SCRIPTURE';
  end if;

  if exists (
    select 1
    from competition.point_ledger ledger
    join competition.spiritual_activities activity on activity.id = ledger.activity_id
    join legacy_matched_users matched on matched.id = activity.user_id
    where activity.activity_code = 'ROSARY'
      and ledger.user_id <> activity.user_id
  ) then
    raise exception 'LEGACY_IMPORT_CROSS_USER_LEDGER_REFERENCE';
  end if;
end
$$;

select
  (select count(*) from legacy_profiles) as exported_profiles,
  (select count(*) from legacy_profiles where username is not null and btrim(username) <> '' and btrim(username) !~ '^[A-Za-z0-9_]{3,30}$') as invalid_legacy_usernames,
  (select count(*) from legacy_profiles where nullif(btrim(username), '') is null) as missing_legacy_usernames,
  (select count(*) from legacy_profiles where gender is null or lower(btrim(gender)) not in ('male', 'female')) as missing_legacy_gender,
  (select count(*) from legacy_profile_identity_rules where generation_strategy = 'safe_fallback') as moderated_name_fallbacks,
  (select count(*) from legacy_matched_users) as matched_auth_accounts,
  (select count(*) from legacy_profiles) -
    (select count(*) from legacy_matched_users) as skipped_without_auth,
  (select count(*) from legacy_rosary_stats rosary join legacy_matched_users matched on matched.id = rosary.user_id) as rosaries_to_import,
  (select count(*) from legacy_user_xp xp join legacy_matched_users matched on matched.id = xp.user_id) as xp_balances_to_import;

select
  (select count(*) from legacy_matched_users matched left join app.users app_user on app_user.id = matched.id where app_user.id is null) as app_users_to_repair,
  (select count(*) from legacy_matched_users matched left join app.user_profiles profile on profile.user_id = matched.id where profile.user_id is null) as profiles_to_create,
  (select count(*) from legacy_profile_candidates where username_source like 'generated_%') as usernames_to_generate,
  (select count(*) from legacy_profile_candidates where username_source = 'generated_safe_fallback') as safe_username_fallbacks,
  (select count(*) from legacy_profile_candidates where current_gender is null and legacy_gender is null) as genders_requiring_confirmation,
  (select count(*) from legacy_matched_users where lower(role) = 'admin') as legacy_admin_roles_ignored;

select
  matched.id as user_id,
  coalesce(nullif(btrim(concat_ws(' ', matched.first_name, matched.last_name)), ''), '(no legacy name)') as legacy_display_name,
  matched.rosary_count as legacy_rosaries,
  coalesce(xp.total_xp, 0) as legacy_total_xp,
  coalesce(current_rosaries.rosary_count, 0) as current_rosaries_to_replace,
  coalesce(progress.total_xp, 0) as current_total_xp_to_replace,
  candidate.username_candidate as target_username,
  candidate.username_source,
  coalesce(candidate.current_gender, candidate.legacy_gender, 'confirmation_required') as target_gender
from legacy_matched_users matched
join legacy_profile_candidates candidate on candidate.id = matched.id
left join legacy_user_xp xp on xp.user_id = matched.id
left join competition.user_progress progress on progress.user_id = matched.id
left join lateral (
  select count(*)::bigint as rosary_count
  from competition.spiritual_activities activity
  where activity.user_id = matched.id
    and activity.activity_code = 'ROSARY'
) current_rosaries on true
order by matched.id;

\if :mutate

select pg_advisory_xact_lock(
  pg_catalog.hashtextextended('doit4jesus.legacy_user_data_import', 0)
);

lock table
  app.users,
  app.user_profiles,
  competition.spiritual_activities,
  competition.point_ledger,
  competition.user_progress,
  competition.user_badges,
  competition.user_badge_progress,
  competition.user_badge_requirement_progress,
  competition.badge_shares,
  competition.challenge_progress_events,
  competition.leaderboard_periods,
  competition.leaderboard_entries
in share row exclusive mode;

do $$
begin
  if exists (
    select 1
    from legacy_matched_users matched
    left join auth.users auth_user on auth_user.id = matched.id
    where auth_user.id is null
  ) then
    raise exception 'LEGACY_IMPORT_AUTH_USER_CHANGED_AFTER_PREFLIGHT';
  end if;

  perform auth_user.id
  from auth.users auth_user
  join legacy_matched_users matched on matched.id = auth_user.id
  for key share of auth_user;
end
$$;

\if :commit

\o :app_users_backup
\copy (select app_user.* from app.users app_user join legacy_matched_users matched on matched.id = app_user.id order by app_user.id) to stdout with (format csv, header true)
\o
\o :user_profiles_backup
\copy (select profile.* from app.user_profiles profile join legacy_matched_users matched on matched.id = profile.user_id order by profile.user_id) to stdout with (format csv, header true)
\o
\o :spiritual_activities_backup
\copy (select activity.* from competition.spiritual_activities activity join legacy_matched_users matched on matched.id = activity.user_id where activity.activity_code = 'ROSARY' order by activity.user_id, activity.occurred_at, activity.id) to stdout with (format csv, header true)
\o
\o :point_ledger_backup
\copy (select ledger.* from competition.point_ledger ledger join legacy_matched_users matched on matched.id = ledger.user_id order by ledger.user_id, ledger.occurred_at, ledger.id) to stdout with (format csv, header true)
\o
\o :user_progress_backup
\copy (select progress.* from competition.user_progress progress join legacy_matched_users matched on matched.id = progress.user_id order by progress.user_id) to stdout with (format csv, header true)
\o
\o :user_badges_backup
\copy (select user_badge.* from competition.user_badges user_badge join legacy_matched_users matched on matched.id = user_badge.user_id join legacy_first_rosary_badge first_badge on first_badge.badge_id = user_badge.badge_id order by user_badge.user_id, user_badge.sequence_number) to stdout with (format csv, header true)
\o
\o :user_badge_progress_backup
\copy (select progress.* from competition.user_badge_progress progress join legacy_matched_users matched on matched.id = progress.user_id join legacy_first_rosary_badge first_badge on first_badge.badge_id = progress.badge_id order by progress.user_id) to stdout with (format csv, header true)
\o
\o :user_badge_requirement_progress_backup
\copy (select progress.* from competition.user_badge_requirement_progress progress join legacy_matched_users matched on matched.id = progress.user_id join legacy_first_rosary_badge first_badge on first_badge.requirement_id = progress.badge_requirement_id order by progress.user_id) to stdout with (format csv, header true)
\o
\o :badge_shares_backup
\copy (select share.* from competition.badge_shares share join competition.user_badges user_badge on user_badge.id = share.user_badge_id join legacy_matched_users matched on matched.id = user_badge.user_id join legacy_first_rosary_badge first_badge on first_badge.badge_id = user_badge.badge_id order by share.id) to stdout with (format csv, header true)
\o
\o :challenge_progress_events_backup
\copy (select progress_event.* from competition.challenge_progress_events progress_event join competition.spiritual_activities activity on activity.id = progress_event.activity_id join legacy_matched_users matched on matched.id = activity.user_id where activity.activity_code = 'ROSARY' order by progress_event.id) to stdout with (format csv, header true)
\o
\o :leaderboard_periods_backup
\copy (select * from competition.leaderboard_periods order by starts_at, period_type) to stdout with (format csv, header true)
\o
\o :leaderboard_entries_backup
\copy (select * from competition.leaderboard_entries order by period_id, scope_type, scope_reference, user_id) to stdout with (format csv, header true)
\o

\endif

insert into app.users (
  id,
  email,
  status,
  email_verified_at,
  last_login_at,
  created_at,
  updated_at
)
select
  auth_user.id,
  auth_user.email,
  'active',
  auth_user.email_confirmed_at,
  auth_user.last_sign_in_at,
  coalesce(auth_user.created_at, matched.created_at),
  now()
from legacy_matched_users matched
join auth.users auth_user on auth_user.id = matched.id
on conflict (id) do update
set
  email = coalesce(app.users.email, excluded.email),
  email_verified_at = coalesce(app.users.email_verified_at, excluded.email_verified_at),
  last_login_at = coalesce(app.users.last_login_at, excluded.last_login_at),
  updated_at = now();

insert into app.user_profiles (
  user_id,
  display_name,
  username,
  avatar_url,
  title,
  gender,
  preferred_language,
  timezone,
  country_code,
  profile_setup_completed_at,
  created_at,
  updated_at
)
select
  matched.id,
  candidate.display_name,
  candidate.username_candidate,
  candidate.avatar_url,
  candidate.title,
  candidate.legacy_gender,
  coalesce(candidate.preferred_language, 'en'),
  'UTC',
  candidate.country_code,
  null,
  matched.created_at,
  now()
from legacy_matched_users matched
join legacy_profile_candidates candidate on candidate.id = matched.id
on conflict (user_id) do nothing;

update app.user_profiles profile
set
  display_name = coalesce(nullif(btrim(profile.display_name), ''), candidate.display_name),
  username = coalesce(nullif(btrim(profile.username::text), ''), candidate.username_candidate),
  avatar_url = coalesce(nullif(btrim(profile.avatar_url), ''), candidate.avatar_url),
  title = coalesce(nullif(btrim(profile.title), ''), candidate.title),
  gender = coalesce(profile.gender, candidate.legacy_gender),
  preferred_language = case
    when nullif(btrim(profile.preferred_language), '') is not null then profile.preferred_language
    else coalesce(candidate.preferred_language, 'en')
  end,
  country_code = coalesce(profile.country_code, candidate.country_code),
  updated_at = now()
from legacy_profile_candidates candidate
where profile.user_id = candidate.id;

update app.user_profiles profile
set
  profile_setup_completed_at = null,
  updated_at = now()
from legacy_profile_candidates candidate
where profile.user_id = candidate.id
  and candidate.current_gender is null
  and candidate.legacy_gender is null
  and profile.gender is null;

update app.user_profiles profile
set
  profile_setup_completed_at = now(),
  updated_at = now()
from legacy_matched_users matched
where profile.user_id = matched.id
  and profile.profile_setup_completed_at is null
  and nullif(btrim(profile.display_name), '') is not null
  and profile.gender in ('male', 'female')
  and profile.country_code is not null;

create temporary table legacy_replaced_rosary_activities on commit drop as
select activity.id
from competition.spiritual_activities activity
join legacy_matched_users matched on matched.id = activity.user_id
where activity.activity_code = 'ROSARY';

alter table legacy_replaced_rosary_activities add primary key (id);

update competition.challenge_progress_events progress_event
set activity_id = null
from legacy_replaced_rosary_activities replaced
where progress_event.activity_id = replaced.id;

delete from competition.point_ledger ledger
using legacy_matched_users matched
where ledger.user_id = matched.id;

delete from competition.spiritual_activities activity
using legacy_matched_users matched
where activity.user_id = matched.id
  and activity.activity_code = 'ROSARY';

select set_config('api.record_spiritual_activity_badges', 'true', true);

insert into competition.spiritual_activities (
  id,
  user_id,
  activity_code,
  occurred_at,
  completed_at,
  duration_seconds,
  quantity,
  verification_status,
  source,
  country_code,
  idempotency_key,
  metadata,
  created_at
)
select
  rosary.id,
  rosary.user_id,
  'ROSARY',
  occurred.occurred_at,
  occurred.occurred_at,
  null,
  1,
  'self_reported',
  'import',
  'US'::char(2),
  'legacy-rosary:' || rosary.id::text,
  jsonb_strip_nulls(jsonb_build_object(
    'legacyRosaryStatId', rosary.id,
    'legacyCompletedDate', rosary.completed_at,
    'legacyJoinRosaryUserId', rosary.join_rosary_user_id,
    'legacyCreatedAt', rosary.created_at
  )),
  coalesce(rosary.created_at, occurred.occurred_at)
from legacy_rosary_stats rosary
join legacy_matched_users matched on matched.id = rosary.user_id
join app.user_profiles profile on profile.user_id = rosary.user_id
cross join lateral (
  select pg_catalog.timezone(
    case
      when exists (
        select 1
        from pg_catalog.pg_timezone_names timezone_name
        where timezone_name.name = profile.timezone
      ) then profile.timezone
      else 'UTC'
    end,
    rosary.completed_at::timestamp + interval '12 hours'
  ) as occurred_at
) occurred;

select set_config('api.record_spiritual_activity_badges', '', true);

create temporary table legacy_final_rosary_totals on commit drop as
select
  matched.id as user_id,
  count(activity.id)::integer as rosary_count,
  min(activity.occurred_at) as first_rosary_at,
  (array_agg(activity.id order by activity.occurred_at, activity.id))[1] as first_activity_id,
  max(activity.occurred_at) as last_rosary_at
from legacy_matched_users matched
left join competition.spiritual_activities activity
  on activity.user_id = matched.id
  and activity.activity_code = 'ROSARY'
group by matched.id;

delete from competition.user_badges user_badge
using legacy_final_rosary_totals total, legacy_first_rosary_badge first_badge
where user_badge.user_id = total.user_id
  and user_badge.badge_id = first_badge.badge_id
  and (total.rosary_count = 0 or user_badge.sequence_number <> 1);

insert into competition.user_badge_requirement_progress (
  user_id,
  badge_requirement_id,
  current_value,
  required_value,
  completed_at,
  updated_at
)
select
  total.user_id,
  first_badge.requirement_id,
  total.rosary_count,
  first_badge.required_value,
  case when total.rosary_count >= first_badge.required_value then total.first_rosary_at end,
  now()
from legacy_final_rosary_totals total
cross join legacy_first_rosary_badge first_badge
on conflict (user_id, badge_requirement_id) do update
set
  current_value = excluded.current_value,
  required_value = excluded.required_value,
  completed_at = excluded.completed_at,
  updated_at = now();

insert into competition.user_badge_progress (
  user_id,
  badge_id,
  current_value,
  required_value,
  updated_at
)
select
  total.user_id,
  first_badge.badge_id,
  case when total.rosary_count >= first_badge.required_value then 1 else 0 end,
  1,
  now()
from legacy_final_rosary_totals total
cross join legacy_first_rosary_badge first_badge
on conflict (user_id, badge_id) do update
set
  current_value = excluded.current_value,
  required_value = excluded.required_value,
  updated_at = now();

insert into competition.user_badges (
  user_id,
  badge_id,
  earned_at,
  source_type,
  source_id,
  sequence_number,
  metadata
)
select
  total.user_id,
  first_badge.badge_id,
  total.first_rosary_at,
  'activity',
  total.first_activity_id,
  1,
  jsonb_build_object('requirementsCompleted', 1, 'legacyImport', true)
from legacy_final_rosary_totals total
cross join legacy_first_rosary_badge first_badge
where total.rosary_count >= first_badge.required_value
on conflict (user_id, badge_id, sequence_number) do update
set
  earned_at = excluded.earned_at,
  source_type = excluded.source_type,
  source_id = excluded.source_id,
  metadata = excluded.metadata;

insert into competition.point_ledger (
  id,
  user_id,
  point_rule_id,
  activity_id,
  source_type,
  source_id,
  transaction_type,
  points,
  reason,
  idempotency_key,
  metadata,
  occurred_at,
  created_at
)
select
  xp.id,
  xp.user_id,
  null,
  null,
  'legacy_balance',
  xp.id,
  'adjustment',
  xp.total_xp::integer,
  'Imported legacy XP balance',
  'legacy-user-xp:' || xp.id::text,
  jsonb_build_object(
    'legacyCurrentLevel', xp.current_level,
    'legacyCurrentTitle', xp.current_title,
    'legacyUpdatedAt', xp.updated_at,
    'legacyCreatedAt', xp.created_at
  ),
  xp.updated_at,
  xp.created_at
from legacy_user_xp xp
join legacy_matched_users matched on matched.id = xp.user_id
where xp.total_xp > 0;

with balances as (
  select
    matched.id as user_id,
    coalesce(xp.total_xp, 0) as total_xp,
    greatest(xp.updated_at, rosary_total.last_rosary_at) as last_activity_at
  from legacy_matched_users matched
  left join legacy_user_xp xp on xp.user_id = matched.id
  left join legacy_final_rosary_totals rosary_total on rosary_total.user_id = matched.id
), calculated as (
  select
    balance.*,
    level_definition.level_number
  from balances balance
  cross join lateral (
    select level.level_number
    from competition.level_definitions level
    where level.is_active
      and level.minimum_total_xp <= balance.total_xp
    order by level.minimum_total_xp desc
    limit 1
  ) level_definition
)
insert into competition.user_progress (
  user_id,
  total_xp,
  current_level,
  weekly_points,
  yearly_points,
  lifetime_points,
  last_activity_at,
  version,
  updated_at
)
select
  calculated.user_id,
  calculated.total_xp,
  calculated.level_number,
  0,
  0,
  calculated.total_xp,
  calculated.last_activity_at,
  1,
  now()
from calculated
on conflict (user_id) do update
set
  total_xp = excluded.total_xp,
  current_level = excluded.current_level,
  weekly_points = 0,
  yearly_points = 0,
  lifetime_points = excluded.lifetime_points,
  last_activity_at = excluded.last_activity_at,
  version = competition.user_progress.version + 1,
  updated_at = now();

select competition.refresh_leaderboards(true, now());

do $$
begin
  if exists (
    select 1
    from legacy_matched_users matched
    left join app.user_profiles profile on profile.user_id = matched.id
    where profile.user_id is null
  ) then
    raise exception 'LEGACY_IMPORT_PROFILE_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from legacy_profile_candidates candidate
    join app.user_profiles profile on profile.user_id = candidate.id
    where nullif(btrim(profile.username::text), '') is null
      or (
        candidate.current_username is null
        and profile.username::text <> candidate.username_candidate
      )
  ) then
    raise exception 'LEGACY_IMPORT_USERNAME_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from legacy_profile_candidates candidate
    join app.user_profiles profile on profile.user_id = candidate.id
    where candidate.current_gender is null
      and candidate.legacy_gender is null
      and (
        profile.gender is not null
        or profile.profile_setup_completed_at is not null
      )
  ) then
    raise exception 'LEGACY_IMPORT_GENDER_CONFIRMATION_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from legacy_matched_users matched
    left join legacy_profiles legacy on legacy.id = matched.id
    left join (
      select activity.user_id, count(*)::bigint as rosary_count
      from competition.spiritual_activities activity
      where activity.activity_code = 'ROSARY'
      group by activity.user_id
    ) actual on actual.user_id = matched.id
    where coalesce(actual.rosary_count, 0) <> legacy.rosary_count
  ) then
    raise exception 'LEGACY_IMPORT_ROSARY_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from legacy_matched_users matched
    left join legacy_user_xp xp on xp.user_id = matched.id
    left join competition.user_progress progress on progress.user_id = matched.id
    where progress.user_id is null
      or progress.total_xp <> coalesce(xp.total_xp, 0)
      or progress.lifetime_points <> coalesce(xp.total_xp, 0)
      or progress.weekly_points <> 0
      or progress.yearly_points <> 0
      or progress.current_level <> (
        select level.level_number
        from competition.level_definitions level
        where level.is_active
          and level.minimum_total_xp <= coalesce(xp.total_xp, 0)
        order by level.minimum_total_xp desc
        limit 1
      )
  ) then
    raise exception 'LEGACY_IMPORT_XP_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from competition.point_ledger ledger
    join legacy_matched_users matched on matched.id = ledger.user_id
    where ledger.source_type <> 'legacy_balance'
  ) then
    raise exception 'LEGACY_IMPORT_LEDGER_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from competition.leaderboard_entries entry
    join legacy_matched_users matched on matched.id = entry.user_id
    where entry.points <> 0
  ) then
    raise exception 'LEGACY_IMPORT_LEADERBOARD_XP_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from legacy_final_rosary_totals total
    cross join legacy_first_rosary_badge first_badge
    left join competition.user_badges user_badge
      on user_badge.user_id = total.user_id
      and user_badge.badge_id = first_badge.badge_id
      and user_badge.sequence_number = 1
    where (total.rosary_count > 0) <> (user_badge.id is not null)
  ) then
    raise exception 'LEGACY_IMPORT_BADGE_POSTCONDITION_FAILED';
  end if;

  if exists (
    select 1
    from legacy_final_rosary_totals total
    cross join legacy_first_rosary_badge first_badge
    left join competition.user_badge_requirement_progress requirement_progress
      on requirement_progress.user_id = total.user_id
      and requirement_progress.badge_requirement_id = first_badge.requirement_id
    left join competition.user_badge_progress badge_progress
      on badge_progress.user_id = total.user_id
      and badge_progress.badge_id = first_badge.badge_id
    where requirement_progress.current_value is distinct from total.rosary_count
      or requirement_progress.required_value is distinct from first_badge.required_value
      or badge_progress.current_value is distinct from case when total.rosary_count > 0 then 1 else 0 end
      or badge_progress.required_value is distinct from 1
  ) then
    raise exception 'LEGACY_IMPORT_BADGE_PROGRESS_POSTCONDITION_FAILED';
  end if;
end
$$;

select
  (select count(*) from legacy_matched_users) as imported_users,
  (select count(*) from legacy_rosary_stats rosary join legacy_matched_users matched on matched.id = rosary.user_id) as imported_rosaries,
  (select coalesce(sum(progress.total_xp), 0) from competition.user_progress progress join legacy_matched_users matched on matched.id = progress.user_id) as imported_total_xp;

\if :commit

commit;

\else

rollback;

\endif

\else

rollback;

\endif
