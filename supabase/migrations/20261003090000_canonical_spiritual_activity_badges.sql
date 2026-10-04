-- Make competition.spiritual_activities the sole spiritual-practice ledger.
-- prayer.prayer_events is intentionally retired without copying legacy-only rows.

create or replace function api.refresh_badge_requirement_progress_on_activity_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('api.record_spiritual_activity_badges', true) = 'true' then
    return new;
  end if;

  perform api.refresh_badge_requirement_progress(new.user_id, new.id);
  return new;
end;
$$;

revoke all on function api.refresh_badge_requirement_progress_on_activity_insert()
from public, anon, authenticated;

drop trigger if exists trg_spiritual_activities_refresh_badge_progress
on competition.spiritual_activities;

create trigger trg_spiritual_activities_refresh_badge_progress
after insert on competition.spiritual_activities
for each row execute function api.refresh_badge_requirement_progress_on_activity_insert();

-- Normalize the activity-based badges that predate badge requirement rules.
insert into competition.badge_requirement_definitions (
  badge_id,
  requirement_type,
  required_value,
  description,
  rules,
  display_order,
  translations
)
select
  badge.id,
  source.requirement_type,
  source.required_value,
  source.description,
  source.rules,
  source.display_order,
  source.translations
from (
  values
    ('FIRST_ROSARY', 'rosary_completed', 1, 'Pray your first complete rosary.', '{}'::jsonb, 1::smallint,
      jsonb_build_object('es', jsonb_build_object('description', 'Reza tu primer rosario completo.'))),
    ('SCRIPTURE_SEEKER', 'scripture_reading_sessions', 5, 'Complete five Scripture reading sessions.', '{}'::jsonb, 1::smallint,
      jsonb_build_object('es', jsonb_build_object('description', 'Completa cinco sesiones de lectura de la Escritura.')))
) as source(code, requirement_type, required_value, description, rules, display_order, translations)
join competition.badge_definitions badge on badge.code = source.code
on conflict (badge_id, display_order) do update
set
  requirement_type = excluded.requirement_type,
  required_value = excluded.required_value,
  description = excluded.description,
  rules = excluded.rules,
  translations = excluded.translations;

-- All Scripture-related badge requirements are evaluated from canonical
-- activities; Shield of Faith keeps its existing plan-completed metadata rule.
insert into competition.badge_requirement_activity_rules (
  badge_requirement_id,
  activity_code,
  progress_mode,
  metadata_filter
)
select
  requirement.id,
  source.activity_code,
  source.progress_mode,
  source.metadata_filter
from (
  values
    ('FIRST_ROSARY', 'rosary_completed', 'ROSARY', 'activity_quantity', '{}'::jsonb),
    ('SCRIPTURE_SEEKER', 'scripture_reading_sessions', 'SCRIPTURE', 'activity_quantity', '{}'::jsonb),
    ('SWORD_OF_THE_SPIRIT', 'scripture_reading_sessions', 'SCRIPTURE', 'activity_quantity', '{}'::jsonb),
    ('SHIELD_OF_FAITH', 'scripture_plan_completed', 'SCRIPTURE', 'activity_quantity', '{"planCompleted":true}'::jsonb)
) as source(badge_code, requirement_type, activity_code, progress_mode, metadata_filter)
join competition.badge_definitions badge on badge.code = source.badge_code
join competition.badge_requirement_definitions requirement
  on requirement.badge_id = badge.id
  and requirement.requirement_type = source.requirement_type
on conflict (badge_requirement_id) do update
set
  activity_code = excluded.activity_code,
  progress_mode = excluded.progress_mode,
  metadata_filter = excluded.metadata_filter;

create or replace function api.reconcile_badge_requirement_progress(
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_activity record;
  v_new_badges jsonb := '[]'::jsonb;
  v_evaluated_activities integer := 0;
begin
  for v_activity in
    select distinct activity.user_id, activity.id
    from competition.spiritual_activities activity
    join competition.badge_requirement_activity_rules activity_rule
      on activity_rule.activity_code = activity.activity_code
      and activity.metadata @> activity_rule.metadata_filter
    where p_user_id is null or activity.user_id = p_user_id
    order by activity.user_id, activity.id
  loop
    v_new_badges := v_new_badges || api.refresh_badge_requirement_progress(
      v_activity.user_id,
      v_activity.id
    );
    v_evaluated_activities := v_evaluated_activities + 1;
  end loop;

  return jsonb_build_object(
    'evaluatedActivities', v_evaluated_activities,
    'newBadges', v_new_badges
  );
end;
$$;

revoke all on function api.reconcile_badge_requirement_progress(uuid)
from public, anon, authenticated;
grant execute on function api.reconcile_badge_requirement_progress(uuid)
to service_role;

-- Preserve the RPC's established newBadges response while preventing the
-- canonical insert trigger from performing the same work a second time.
do $$
declare
  v_definition text;
  v_signature regprocedure := 'api.record_spiritual_activity(character varying,timestamp with time zone,timestamp with time zone,integer,integer,character varying,character varying,jsonb)'::regprocedure;
begin
  select pg_get_functiondef(v_signature) into v_definition;

  if position('  insert into competition.spiritual_activities (' in v_definition) = 0
    or position('  returning * into v_activity;' in v_definition) = 0 then
    raise exception 'Unexpected api.record_spiritual_activity definition';
  end if;

  v_definition := replace(
    v_definition,
    '  insert into competition.spiritual_activities (',
    '  perform set_config(''api.record_spiritual_activity_badges'', ''true'', true);' || E'\n\n' ||
    '  insert into competition.spiritual_activities ('
  );
  v_definition := replace(
    v_definition,
    '  returning * into v_activity;',
    '  returning * into v_activity;' || E'\n\n' ||
    '  perform set_config(''api.record_spiritual_activity_badges'', '''', true);'
  );

  execute v_definition;
end;
$$;

-- Repair normalized badge progress and missing awards from historical canonical
-- activities before removing the obsolete parallel ledger.
select api.reconcile_badge_requirement_progress();

-- The account-deletion function previously removed the retired child records.
create or replace function api.delete_user_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := auth.uid();
  v_rosaries_prayed bigint;
begin
  if v_caller_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if v_caller_id <> p_user_id and not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select coalesce(sum(activity.quantity), 0)::bigint
  into v_rosaries_prayed
  from competition.spiritual_activities activity
  where activity.user_id = p_user_id
    and activity.activity_code = 'ROSARY'
    and activity.verification_status in ('self_reported', 'verified');

  update app.deleted_account_rosary_totals
  set rosaries_prayed = rosaries_prayed + v_rosaries_prayed
  where singleton;

  delete from competition.demon_battle_events event_record
  using competition.user_demon_encounters encounter
  where event_record.encounter_id = encounter.id
    and encounter.user_id = p_user_id;

  delete from competition.challenge_progress_events progress_event
  where progress_event.activity_id in (
    select activity.id
    from competition.spiritual_activities activity
    where activity.user_id = p_user_id
  )
  or progress_event.assignment_id in (
    select assignment.id
    from competition.user_challenge_assignments assignment
    where assignment.user_id = p_user_id
  );

  delete from competition.point_ledger ledger
  where ledger.activity_id in (
    select activity.id
    from competition.spiritual_activities activity
    where activity.user_id = p_user_id
  );

  delete from app.users where id = p_user_id;
  delete from auth.users where id = p_user_id;
end;
$$;

revoke all on function api.delete_user_account(uuid) from public, anon;
grant execute on function api.delete_user_account(uuid) to authenticated, service_role;

drop table prayer.prayer_events;

notify pgrst, 'reload schema';
