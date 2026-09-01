-- Remove application-wide city storage and city-scoped aggregates. Church
-- directory city text is intentionally retained for church search and display.

drop function if exists api.search_cities(text, text, integer, integer);
drop function if exists api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text,
  boolean,
  boolean,
  boolean
);
drop function if exists api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text,
  uuid,
  boolean,
  boolean,
  boolean
);
drop function if exists api.record_spiritual_activity(
  varchar,
  timestamptz,
  timestamptz,
  integer,
  integer,
  varchar,
  varchar,
  jsonb
);
drop function if exists api.record_spiritual_activity(
  varchar,
  timestamptz,
  timestamptz,
  integer,
  integer,
  uuid,
  varchar,
  varchar,
  jsonb
);

delete from competition.leaderboard_entries
where scope_type = 'city';

alter table competition.leaderboard_entries
  drop constraint if exists leaderboard_entries_scope_type_check;
alter table competition.leaderboard_entries
  add constraint leaderboard_entries_scope_type_check
  check (scope_type in ('global', 'country'));

delete from prayer.map_markers
where aggregation_level = 'city';

alter table prayer.map_markers
  drop constraint if exists map_markers_aggregation_level_check;
alter table prayer.map_markers
  add constraint map_markers_aggregation_level_check
  check (aggregation_level = 'country');

drop table if exists prayer.city_daily_aggregates;

alter table prayer.prayer_events
  drop column if exists city_id;
alter table competition.spiritual_activities
  drop column if exists city_id;
alter table app.user_profiles
  drop column if exists city_id;

drop table if exists app.cities;

create function api.complete_current_user_profile_setup(
  p_display_name text,
  p_username text,
  p_gender text,
  p_country_code text,
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

  update app.user_profiles profile
  set
    display_name = v_display_name,
    username = nullif(btrim(p_username), ''),
    gender = p_gender,
    country_code = v_country_code::char(2),
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

create function api.record_spiritual_activity(
  p_activity_code varchar,
  p_occurred_at timestamptz,
  p_completed_at timestamptz default null,
  p_duration_seconds integer default null,
  p_quantity integer default 1,
  p_country_code varchar default null,
  p_idempotency_key varchar default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_activity_definition competition.activity_definitions%rowtype;
  v_activity competition.spiritual_activities%rowtype;
  v_point_rule competition.point_rules%rowtype;
  v_assignment record;
  v_new_progress integer;
  v_points integer := 0;
  v_challenge_updates jsonb := '[]'::jsonb;
  v_battle_updates jsonb := '[]'::jsonb;
  v_new_badges jsonb := '[]'::jsonb;
  v_xp_result jsonb := '{}'::jsonb;
  v_existing_result jsonb;
  v_battle_result jsonb;
  v_result jsonb;
  v_battle_encounter_id uuid;
  v_battle_assignment_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  if coalesce(length(trim(p_idempotency_key)), 0) = 0 or length(p_idempotency_key) > 150 then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  if p_quantity is null or p_quantity < 1 then
    raise exception 'INVALID_ACTIVITY_QUANTITY';
  end if;

  insert into platform.idempotency_records (
    user_id, idempotency_key, request_method, request_path, request_hash, expires_at
  )
  values (
    v_user_id,
    p_idempotency_key,
    'POST',
    '/api/v1/activities',
    md5(coalesce(p_activity_code, '') || ':' || coalesce(p_occurred_at::text, '')),
    now() + interval '24 hours'
  )
  on conflict (user_id, idempotency_key) do nothing;

  if not found then
    select response_body
    into v_existing_result
    from platform.idempotency_records
    where user_id = v_user_id and idempotency_key = p_idempotency_key
    for update;

    if v_existing_result is null then
      raise exception 'IDEMPOTENCY_IN_PROGRESS';
    end if;

    return jsonb_set(v_existing_result, '{replayed}', 'true'::jsonb, true);
  end if;

  select *
  into v_activity_definition
  from competition.activity_definitions
  where code = upper(trim(p_activity_code))
    and is_active;

  if not found then
    raise exception 'ACTIVITY_DEFINITION_NOT_FOUND';
  end if;

  insert into competition.spiritual_activities (
    user_id, activity_code, occurred_at, completed_at, duration_seconds,
    quantity, verification_status, source, country_code, idempotency_key,
    metadata
  )
  values (
    v_user_id, v_activity_definition.code, p_occurred_at, p_completed_at,
    p_duration_seconds, p_quantity, 'self_reported', 'manual',
    upper(p_country_code)::char(2), p_idempotency_key,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_activity;

  for v_assignment in
    select
      assignment.id,
      assignment.target_quantity,
      assignment.current_progress,
      definition.id as definition_id,
      definition.title
    from competition.user_challenge_assignments assignment
    join competition.challenge_definitions definition
      on definition.id = assignment.challenge_definition_id
    where assignment.user_id = v_user_id
      and assignment.status = 'active'
      and definition.activity_code = v_activity.activity_code
      and assignment.starts_at <= v_activity.occurred_at
      and assignment.expires_at > v_activity.occurred_at
    for update of assignment
  loop
    v_new_progress := least(
      v_assignment.target_quantity,
      v_assignment.current_progress + v_activity.quantity
    );

    update competition.user_challenge_assignments
    set
      current_progress = v_new_progress,
      status = case
        when v_new_progress = v_assignment.target_quantity then 'completed'
        else 'active'
      end,
      completed_at = case
        when v_new_progress = v_assignment.target_quantity then now()
        else null
      end
    where id = v_assignment.id;

    insert into competition.challenge_progress_events (
      assignment_id, activity_id, increment_amount, previous_progress,
      resulting_progress, idempotency_key
    )
    values (
      v_assignment.id, v_activity.id, v_activity.quantity,
      v_assignment.current_progress, v_new_progress,
      'activity-challenge:' || md5(p_idempotency_key || v_assignment.id::text)
    );

    v_challenge_updates := v_challenge_updates || jsonb_build_array(
      jsonb_build_object(
        'assignmentId', v_assignment.id,
        'previousProgress', v_assignment.current_progress,
        'currentProgress', v_new_progress,
        'completed', v_new_progress = v_assignment.target_quantity
      )
    );
  end loop;

  select *
  into v_point_rule
  from competition.point_rules
  where activity_code = v_activity.activity_code
    and is_active
    and effective_from <= v_activity.occurred_at
    and (effective_until is null or effective_until > v_activity.occurred_at)
  order by effective_from desc
  limit 1;

  if found then
    v_points := v_point_rule.points * v_activity.quantity;

    insert into competition.point_ledger (
      user_id, point_rule_id, activity_id, source_type, source_id,
      transaction_type, points, reason, idempotency_key, metadata, occurred_at
    )
    values (
      v_user_id, v_point_rule.id, v_activity.id, 'activity', v_activity.id,
      'award', v_points, v_point_rule.name,
      'activity-points:' || md5(p_idempotency_key),
      jsonb_build_object('activityCode', v_activity.activity_code),
      v_activity.occurred_at
    );

    v_xp_result := api.award_user_xp(
      v_user_id,
      v_points,
      v_activity.occurred_at
    );
  end if;

  v_new_badges := api.refresh_badge_requirement_progress(
    v_user_id,
    v_activity.id
  );

  select encounter.id, assignment.id
  into v_battle_encounter_id, v_battle_assignment_id
  from competition.user_demon_defense_assignments assignment
  join competition.user_demon_encounters encounter
    on encounter.id = assignment.encounter_id
  join competition.demon_defense_activity_rules activity_rule
    on activity_rule.defense_id = assignment.defense_id
  where encounter.user_id = v_user_id
    and encounter.status = 'active'
    and assignment.status = 'assigned'
    and activity_rule.activity_code = v_activity.activity_code
    and v_activity.metadata @> activity_rule.metadata_filter
  order by assignment.assigned_at
  limit 1;

  if found then
    v_battle_result := api.complete_demon_defense(
      v_battle_encounter_id,
      v_battle_assignment_id,
      'activity-defense:' || md5(
        p_idempotency_key || v_battle_assignment_id::text
      )
    );

    v_battle_updates := jsonb_build_array(v_battle_result);
  end if;

  insert into platform.outbox_events (
    aggregate_type,
    aggregate_id,
    event_type,
    payload
  )
  values (
    'spiritual_activity',
    v_activity.id,
    'spiritual_activity.recorded',
    jsonb_build_object(
      'userId', v_user_id,
      'activityCode', v_activity.activity_code,
      'quantity', v_activity.quantity
    )
  );

  v_result := jsonb_build_object(
    'replayed', false,
    'activity', to_jsonb(v_activity),
    'progressUpdates', v_challenge_updates,
    'battleUpdates', v_battle_updates,
    'newBadges', v_new_badges,
    'xp', v_xp_result
  );

  update platform.idempotency_records
  set
    response_status = 201,
    response_body = v_result,
    completed_at = now(),
    locked_until = null
  where user_id = v_user_id
    and idempotency_key = p_idempotency_key;

  return v_result;
end;
$$;

revoke all on function api.complete_current_user_profile_setup(
  text,
  text,
  text,
  text,
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
  boolean,
  boolean,
  boolean
)
to authenticated, service_role;

revoke all on function api.record_spiritual_activity(
  varchar,
  timestamptz,
  timestamptz,
  integer,
  integer,
  varchar,
  varchar,
  jsonb
)
from public, anon;

grant execute on function api.record_spiritual_activity(
  varchar,
  timestamptz,
  timestamptz,
  integer,
  integer,
  varchar,
  varchar,
  jsonb
)
to authenticated, service_role;

notify pgrst, 'reload schema';
