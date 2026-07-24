-- Activity-to-defense rules and transactional API functions for the
-- spiritual-battle system. All mutations remain server-calculated.

-- A completed defense still needs an auditable event when its virtue is already
-- at the configured maximum, so zero-delta clamp events are valid.
alter table competition.virtue_events
  drop constraint virtue_events_delta_check;

create table competition.badge_requirement_activity_rules (
  badge_requirement_id uuid primary key
    references competition.badge_requirement_definitions(id) on delete cascade,
  activity_code varchar(50) not null
    references competition.activity_definitions(code),
  progress_mode varchar(30) not null,
  metadata_filter jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (progress_mode in ('activity_quantity', 'distinct_days', 'consecutive_days'))
);

create index idx_badge_requirement_activity_rules_activity
  on competition.badge_requirement_activity_rules (activity_code);

create table competition.demon_defense_activity_rules (
  defense_id uuid primary key
    references competition.demon_defenses(id) on delete cascade,
  activity_code varchar(50) not null
    references competition.activity_definitions(code),
  metadata_filter jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_demon_defense_activity_rules_activity
  on competition.demon_defense_activity_rules (activity_code);

create table competition.user_badge_requirement_progress (
  user_id uuid not null references app.users(id) on delete cascade,
  badge_requirement_id uuid not null
    references competition.badge_requirement_definitions(id) on delete cascade,
  current_value integer not null default 0,
  required_value integer not null,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, badge_requirement_id),
  check (current_value >= 0),
  check (required_value > 0)
);

create index idx_user_badge_requirement_progress_user
  on competition.user_badge_requirement_progress (user_id, updated_at desc);

create trigger trg_badge_requirement_activity_rules_updated_at
before update on competition.badge_requirement_activity_rules
for each row execute function platform.set_updated_at();

create trigger trg_demon_defense_activity_rules_updated_at
before update on competition.demon_defense_activity_rules
for each row execute function platform.set_updated_at();

create trigger trg_user_badge_requirement_progress_updated_at
before update on competition.user_badge_requirement_progress
for each row execute function platform.set_updated_at();

alter table competition.badge_requirement_activity_rules enable row level security;
alter table competition.demon_defense_activity_rules enable row level security;
alter table competition.user_badge_requirement_progress enable row level security;

grant select on
  competition.badge_requirement_activity_rules,
  competition.demon_defense_activity_rules,
  competition.user_badge_requirement_progress
to authenticated;

grant all privileges on
  competition.badge_requirement_activity_rules,
  competition.demon_defense_activity_rules,
  competition.user_badge_requirement_progress
to service_role;

create policy badge_requirement_activity_rules_select_authenticated
on competition.badge_requirement_activity_rules
for select to authenticated
using (true);

create policy demon_defense_activity_rules_select_authenticated
on competition.demon_defense_activity_rules
for select to authenticated
using (true);

create policy user_badge_requirement_progress_select_own
on competition.user_badge_requirement_progress
for select to authenticated
using ((select auth.uid()) = user_id);

-- Internal helpers are intentionally not granted to authenticated users.
create or replace function api.initialize_user_virtues(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
begin
  insert into competition.user_virtues (user_id, virtue_code, current_value)
  select p_user_id, definition.code, definition.default_value
  from competition.virtue_definitions definition
  where definition.is_active
  on conflict (user_id, virtue_code) do nothing;
end;
$$;

create or replace function api.award_user_xp(
  p_user_id uuid,
  p_points integer,
  p_occurred_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_initial_level integer;
  v_total_xp bigint;
  v_level integer;
begin
  if p_points < 0 then
    raise exception 'INVALID_XP_AWARD';
  end if;

  select level_number
  into v_initial_level
  from competition.level_definitions
  where is_active
  order by minimum_total_xp
  limit 1;

  if v_initial_level is null then
    raise exception 'LEVEL_DEFINITIONS_REQUIRED';
  end if;

  insert into competition.user_progress (user_id, current_level)
  values (p_user_id, v_initial_level)
  on conflict (user_id) do nothing;

  select total_xp + p_points
  into v_total_xp
  from competition.user_progress
  where user_id = p_user_id
  for update;

  select level_number
  into v_level
  from competition.level_definitions
  where is_active
    and minimum_total_xp <= v_total_xp
  order by minimum_total_xp desc
  limit 1;

  if v_level is null then
    v_level := v_initial_level;
  end if;

  update competition.user_progress
  set
    total_xp = v_total_xp,
    current_level = v_level,
    weekly_points = weekly_points + p_points,
    yearly_points = yearly_points + p_points,
    lifetime_points = lifetime_points + p_points,
    last_activity_at = greatest(coalesce(last_activity_at, p_occurred_at), p_occurred_at),
    version = version + 1
  where user_id = p_user_id;

  return jsonb_build_object('points', p_points, 'totalXp', v_total_xp, 'currentLevel', v_level);
end;
$$;

create or replace function api.refresh_badge_requirement_progress(
  p_user_id uuid,
  p_activity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_activity competition.spiritual_activities%rowtype;
  v_rule record;
  v_current_value integer;
  v_required_value integer;
  v_completed_requirements integer;
  v_total_requirements integer;
  v_user_badge_id uuid;
  v_new_badges jsonb := '[]'::jsonb;
begin
  select *
  into v_activity
  from competition.spiritual_activities
  where id = p_activity_id
    and user_id = p_user_id;

  if not found then
    raise exception 'ACTIVITY_NOT_FOUND';
  end if;

  for v_rule in
    select
      requirement.id as requirement_id,
      requirement.badge_id,
      requirement.required_value,
      activity_rule.progress_mode,
      activity_rule.metadata_filter,
      activity_rule.activity_code,
      badge.code as badge_code
    from competition.badge_requirement_activity_rules activity_rule
    join competition.badge_requirement_definitions requirement
      on requirement.id = activity_rule.badge_requirement_id
    join competition.badge_definitions badge
      on badge.id = requirement.badge_id
    where activity_rule.activity_code = v_activity.activity_code
      and v_activity.metadata @> activity_rule.metadata_filter
  loop
    v_required_value := v_rule.required_value;

    if v_rule.progress_mode = 'activity_quantity' then
      select coalesce(sum(activity.quantity), 0)::integer
      into v_current_value
      from competition.spiritual_activities activity
      where activity.user_id = p_user_id
        and activity.activity_code = v_rule.activity_code
        and activity.metadata @> v_rule.metadata_filter;
    elsif v_rule.progress_mode = 'distinct_days' then
      select count(distinct activity.occurred_at::date)::integer
      into v_current_value
      from competition.spiritual_activities activity
      where activity.user_id = p_user_id
        and activity.activity_code = v_rule.activity_code
        and activity.metadata @> v_rule.metadata_filter;
    else
      with activity_days as (
        select distinct activity.occurred_at::date as activity_day
        from competition.spiritual_activities activity
        where activity.user_id = p_user_id
          and activity.activity_code = v_rule.activity_code
          and activity.metadata @> v_rule.metadata_filter
          and activity.occurred_at::date <= v_activity.occurred_at::date
      ), grouped_days as (
        select
          activity_day,
          activity_day - (row_number() over (order by activity_day))::integer as streak_group
        from activity_days
      )
      select count(*)::integer
      into v_current_value
      from grouped_days
      where streak_group = (
        select streak_group
        from grouped_days
        where activity_day = v_activity.occurred_at::date
      );
    end if;

    insert into competition.user_badge_requirement_progress (
      user_id,
      badge_requirement_id,
      current_value,
      required_value,
      completed_at
    )
    values (
      p_user_id,
      v_rule.requirement_id,
      v_current_value,
      v_required_value,
      case when v_current_value >= v_required_value then now() else null end
    )
    on conflict (user_id, badge_requirement_id) do update
    set
      current_value = excluded.current_value,
      required_value = excluded.required_value,
      completed_at = case
        when excluded.current_value >= excluded.required_value
          then coalesce(competition.user_badge_requirement_progress.completed_at, now())
        else null
      end;

    select
      count(*) filter (where progress.current_value >= progress.required_value),
      count(*)
    into v_completed_requirements, v_total_requirements
    from competition.badge_requirement_definitions requirement
    left join competition.user_badge_requirement_progress progress
      on progress.badge_requirement_id = requirement.id
      and progress.user_id = p_user_id
    where requirement.badge_id = v_rule.badge_id;

    insert into competition.user_badge_progress (
      user_id,
      badge_id,
      current_value,
      required_value
    )
    values (p_user_id, v_rule.badge_id, v_completed_requirements, v_total_requirements)
    on conflict (user_id, badge_id) do update
    set
      current_value = excluded.current_value,
      required_value = excluded.required_value;

    if v_total_requirements > 0 and v_completed_requirements = v_total_requirements then
      v_user_badge_id := null;

      insert into competition.user_badges (
        user_id,
        badge_id,
        source_type,
        source_id,
        sequence_number,
        metadata
      )
      select p_user_id, v_rule.badge_id, 'activity', p_activity_id, 1,
        jsonb_build_object('requirementsCompleted', v_total_requirements)
      where not exists (
        select 1
        from competition.user_badges
        where user_id = p_user_id
          and badge_id = v_rule.badge_id
      )
      returning id into v_user_badge_id;

      if v_user_badge_id is not null then
        insert into app.notifications (
          user_id,
          notification_type,
          title,
          body,
          action_url,
          payload
        )
        values (
          p_user_id,
          'equipment_unlocked',
          format('Equipment unlocked: %s', v_rule.badge_code),
          'Your completed virtues and habits unlocked new equipment.',
          '/badges',
          jsonb_build_object('badgeId', v_rule.badge_id, 'badgeCode', v_rule.badge_code)
        );

        v_new_badges := v_new_badges || jsonb_build_array(
          jsonb_build_object('id', v_rule.badge_id, 'code', v_rule.badge_code)
        );
      end if;
    end if;
  end loop;

  return v_new_badges;
end;
$$;

create or replace function api.start_demon_encounter(
  p_demon_code varchar,
  p_idempotency_key varchar
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_demon competition.demon_definitions%rowtype;
  v_encounter competition.user_demon_encounters%rowtype;
  v_assignment competition.user_demon_defense_assignments%rowtype;
  v_defense_id uuid;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  if coalesce(length(trim(p_idempotency_key)), 0) = 0 or length(p_idempotency_key) > 150 then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  insert into platform.idempotency_records (
    user_id, idempotency_key, request_method, request_path, request_hash, expires_at
  )
  values (
    v_user_id,
    p_idempotency_key,
    'POST',
    '/api/v1/encounters',
    md5(coalesce(p_demon_code, '')),
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
  into v_demon
  from competition.demon_definitions
  where code = upper(trim(p_demon_code))
    and is_active;

  if not found then
    raise exception 'DEMON_NOT_FOUND';
  end if;

  perform api.initialize_user_virtues(v_user_id);

  if exists (
    select 1
    from competition.user_demon_encounters
    where user_id = v_user_id
      and demon_id = v_demon.id
      and status = 'active'
  ) then
    raise exception 'ENCOUNTER_ALREADY_ACTIVE';
  end if;

  select id
  into v_defense_id
  from competition.demon_defenses
  where demon_id = v_demon.id
  order by code
  limit 1;

  if v_defense_id is null then
    raise exception 'DEMON_DEFENSES_REQUIRED';
  end if;

  insert into competition.user_demon_encounters (
    user_id, demon_id, max_hp, current_hp, metadata
  )
  values (
    v_user_id, v_demon.id, v_demon.max_hp, v_demon.max_hp,
    jsonb_build_object('startedBy', 'api')
  )
  returning * into v_encounter;

  insert into competition.user_demon_defense_assignments (
    encounter_id, defense_id, assignment_sequence
  )
  values (v_encounter.id, v_defense_id, 1)
  returning * into v_assignment;

  insert into app.notifications (
    user_id, notification_type, title, body, action_url, payload
  )
  values (
    v_user_id,
    'demon_defense_assigned',
    format('A defense is ready against %s', v_demon.name),
    'Complete the assigned defense to strengthen a virtue and weaken the demon.',
    format('/battle/encounters/%s', v_encounter.id),
    jsonb_build_object(
      'encounterId', v_encounter.id,
      'assignmentId', v_assignment.id,
      'demonCode', v_demon.code
    )
  );

  insert into platform.outbox_events (aggregate_type, aggregate_id, event_type, payload)
  values (
    'demon_encounter',
    v_encounter.id,
    'demon_encounter.started',
    jsonb_build_object('userId', v_user_id, 'demonCode', v_demon.code)
  );

  v_result := jsonb_build_object(
    'replayed', false,
    'encounter', to_jsonb(v_encounter),
    'assignment', to_jsonb(v_assignment)
  );

  update platform.idempotency_records
  set response_status = 201, response_body = v_result, completed_at = now(), locked_until = null
  where user_id = v_user_id and idempotency_key = p_idempotency_key;

  return v_result;
end;
$$;

create or replace function api.complete_demon_defense(
  p_encounter_id uuid,
  p_assignment_id uuid,
  p_idempotency_key varchar
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_encounter competition.user_demon_encounters%rowtype;
  v_assignment competition.user_demon_defense_assignments%rowtype;
  v_defense competition.demon_defenses%rowtype;
  v_reward competition.demon_defeat_rewards%rowtype;
  v_previous_virtue smallint;
  v_resulting_virtue smallint;
  v_defense_previous_virtue smallint;
  v_defense_resulting_virtue smallint;
  v_virtue_event_id uuid;
  v_defeat_virtue_event_id uuid;
  v_previous_hp smallint;
  v_resulting_hp smallint;
  v_xp_award integer := 0;
  v_xp_result jsonb := '{}'::jsonb;
  v_next_defense_id uuid;
  v_next_assignment competition.user_demon_defense_assignments%rowtype;
  v_existing_result jsonb;
  v_result jsonb;
  v_virtue_max smallint;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  if coalesce(length(trim(p_idempotency_key)), 0) = 0 or length(p_idempotency_key) > 150 then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  insert into platform.idempotency_records (
    user_id, idempotency_key, request_method, request_path, request_hash, expires_at
  )
  values (
    v_user_id,
    p_idempotency_key,
    'POST',
    format('/api/v1/encounters/%s/defenses/%s/complete', p_encounter_id, p_assignment_id),
    md5(p_encounter_id::text || ':' || p_assignment_id::text),
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
  into v_encounter
  from competition.user_demon_encounters
  where id = p_encounter_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'ENCOUNTER_NOT_FOUND';
  end if;

  if v_encounter.status <> 'active' then
    raise exception 'ENCOUNTER_NOT_ACTIVE';
  end if;

  select *
  into v_assignment
  from competition.user_demon_defense_assignments
  where id = p_assignment_id
    and encounter_id = v_encounter.id
  for update;

  if not found then
    raise exception 'DEFENSE_ASSIGNMENT_NOT_FOUND';
  end if;

  if v_assignment.status <> 'assigned' then
    raise exception 'DEFENSE_ASSIGNMENT_NOT_ACTIVE';
  end if;

  select *
  into v_defense
  from competition.demon_defenses
  where id = v_assignment.defense_id
    and demon_id = v_encounter.demon_id;

  if not found then
    raise exception 'DEFENSE_DOES_NOT_MATCH_ENCOUNTER';
  end if;

  perform api.initialize_user_virtues(v_user_id);

  select virtue_max
  into v_virtue_max
  from competition.game_balance_config
  where id = true;

  select current_value
  into v_previous_virtue
  from competition.user_virtues
  where user_id = v_user_id
    and virtue_code = v_defense.reward_virtue_code
  for update;

  v_resulting_virtue := least(v_virtue_max, v_previous_virtue + v_defense.virtue_increase);
  v_defense_previous_virtue := v_previous_virtue;
  v_defense_resulting_virtue := v_resulting_virtue;
  v_previous_hp := v_encounter.current_hp;
  v_resulting_hp := greatest(0, v_previous_hp - v_defense.demon_damage);

  update competition.user_virtues
  set current_value = v_resulting_virtue, version = version + 1
  where user_id = v_user_id
    and virtue_code = v_defense.reward_virtue_code;

  update competition.user_demon_defense_assignments
  set status = 'completed', completed_at = now()
  where id = v_assignment.id
  returning * into v_assignment;

  update competition.user_demon_encounters
  set
    current_hp = v_resulting_hp,
    status = case when v_resulting_hp = 0 then 'defeated' else 'active' end,
    defeated_at = case when v_resulting_hp = 0 then now() else null end,
    ended_at = case when v_resulting_hp = 0 then now() else null end,
    version = version + 1
  where id = v_encounter.id
  returning * into v_encounter;

  insert into competition.virtue_events (
    user_id, virtue_code, encounter_id, source_type, source_id,
    previous_value, delta, resulting_value, idempotency_key, metadata
  )
  values (
    v_user_id, v_defense.reward_virtue_code, v_encounter.id, 'demon_defense', v_assignment.id,
    v_previous_virtue, v_resulting_virtue - v_previous_virtue, v_resulting_virtue,
    'defense-virtue:' || md5(p_idempotency_key),
    jsonb_build_object('defenseCode', v_defense.code)
  )
  returning id into v_virtue_event_id;

  insert into competition.demon_battle_events (
    encounter_id, event_type, defense_assignment_id, virtue_event_id,
    previous_hp, demon_damage, resulting_hp, idempotency_key, metadata
  )
  values (
    v_encounter.id, 'defense_completed', v_assignment.id, v_virtue_event_id,
    v_previous_hp, v_defense.demon_damage, v_resulting_hp,
    'battle-defense:' || md5(p_idempotency_key),
    jsonb_build_object('defenseCode', v_defense.code)
  );

  if v_resulting_hp = 0 then
    select *
    into v_reward
    from competition.demon_defeat_rewards
    where demon_id = v_encounter.demon_id;

    if not found then
      raise exception 'DEMON_DEFEAT_REWARD_REQUIRED';
    end if;

    select current_value
    into v_previous_virtue
    from competition.user_virtues
    where user_id = v_user_id
      and virtue_code = v_reward.virtue_code
    for update;

    v_resulting_virtue := least(v_virtue_max, v_previous_virtue + v_reward.virtue_increase);

    update competition.user_virtues
    set current_value = v_resulting_virtue, version = version + 1
    where user_id = v_user_id
      and virtue_code = v_reward.virtue_code;

    insert into competition.virtue_events (
      user_id, virtue_code, encounter_id, source_type, source_id,
      previous_value, delta, resulting_value, idempotency_key, metadata
    )
    values (
      v_user_id, v_reward.virtue_code, v_encounter.id, 'demon_defeat', v_encounter.id,
      v_previous_virtue, v_resulting_virtue - v_previous_virtue, v_resulting_virtue,
      'defeat-virtue:' || md5(p_idempotency_key),
      jsonb_build_object('xpReward', v_reward.xp_reward)
    )
    returning id into v_defeat_virtue_event_id;

    insert into competition.demon_battle_events (
      encounter_id, event_type, virtue_event_id,
      previous_hp, demon_damage, resulting_hp, idempotency_key, metadata
    )
    values (
      v_encounter.id, 'demon_defeated', v_defeat_virtue_event_id,
      0, 0, 0,
      'battle-defeat:' || md5(p_idempotency_key),
      jsonb_build_object('xpReward', v_reward.xp_reward)
    );

    v_xp_award := v_reward.xp_reward;

    insert into competition.point_ledger (
      user_id, source_type, source_id, transaction_type, points, reason, idempotency_key, metadata
    )
    values (
      v_user_id, 'demon_defeat', v_encounter.id, 'award', v_xp_award,
      'Defeated a demon', 'defeat-xp:' || md5(p_idempotency_key),
      jsonb_build_object('encounterId', v_encounter.id)
    );

    v_xp_result := api.award_user_xp(v_user_id, v_xp_award, now());

    insert into app.notifications (
      user_id, notification_type, title, body, action_url, payload
    )
    values (
      v_user_id,
      'demon_defeated',
      'Demon defeated',
      'Your faithful defense brought this encounter to an end.',
      format('/battle/encounters/%s', v_encounter.id),
      jsonb_build_object('encounterId', v_encounter.id, 'xpAwarded', v_xp_award)
    );
  else
    if not exists (
      select 1
      from competition.user_demon_defense_assignments
      where encounter_id = v_encounter.id
        and status = 'assigned'
    ) then
      select defense.id
      into v_next_defense_id
      from competition.demon_defenses defense
      where defense.demon_id = v_encounter.demon_id
        and not exists (
          select 1
          from competition.user_demon_defense_assignments assignment
          where assignment.encounter_id = v_encounter.id
            and assignment.defense_id = defense.id
        )
      order by defense.code
      limit 1;

      if v_next_defense_id is not null then
        insert into competition.user_demon_defense_assignments (
          encounter_id, defense_id, assignment_sequence
        )
        values (
          v_encounter.id,
          v_next_defense_id,
          coalesce((
            select max(assignment_sequence) + 1
            from competition.user_demon_defense_assignments
            where encounter_id = v_encounter.id
          ), 1)
        )
        returning * into v_next_assignment;
      end if;
    end if;
  end if;

  insert into app.notifications (
    user_id, notification_type, title, body, action_url, payload
  )
  values (
    v_user_id,
    'demon_defense_completed',
    'Defense completed',
    'A virtue has grown and the demon has been weakened.',
    format('/battle/encounters/%s', v_encounter.id),
    jsonb_build_object(
      'encounterId', v_encounter.id,
      'assignmentId', v_assignment.id,
      'virtueCode', v_defense.reward_virtue_code,
      'virtueDelta', v_defense_resulting_virtue - v_defense_previous_virtue,
      'demonDamage', v_defense.demon_damage
    )
  );

  if v_next_assignment.id is not null then
    insert into app.notifications (
      user_id, notification_type, title, body, action_url, payload
    )
    values (
      v_user_id,
      'demon_defense_assigned',
      'Your next defense is ready',
      'Continue the encounter with the next concrete defense.',
      format('/battle/encounters/%s', v_encounter.id),
      jsonb_build_object('encounterId', v_encounter.id, 'assignmentId', v_next_assignment.id)
    );
  end if;

  insert into platform.outbox_events (aggregate_type, aggregate_id, event_type, payload)
  values (
    'demon_encounter',
    v_encounter.id,
    case when v_encounter.status = 'defeated' then 'demon_encounter.defeated' else 'demon_defense.completed' end,
    jsonb_build_object(
      'userId', v_user_id,
      'assignmentId', v_assignment.id,
      'demonDamage', v_defense.demon_damage,
      'xpAwarded', v_xp_award
    )
  );

  v_result := jsonb_build_object(
    'replayed', false,
    'encounter', to_jsonb(v_encounter),
    'completedAssignment', to_jsonb(v_assignment),
    'nextAssignment', case when v_next_assignment.id is null then null else to_jsonb(v_next_assignment) end,
    'virtue', jsonb_build_object(
      'code', v_defense.reward_virtue_code,
      'previousValue', v_defense_previous_virtue,
      'currentValue', v_defense_resulting_virtue
    ),
    'demonDamage', v_defense.demon_damage,
    'xpAwarded', v_xp_award,
    'xp', v_xp_result,
    'newBadges', '[]'::jsonb
  );

  update platform.idempotency_records
  set response_status = 200, response_body = v_result, completed_at = now(), locked_until = null
  where user_id = v_user_id and idempotency_key = p_idempotency_key;

  return v_result;
end;
$$;

create or replace function api.abandon_demon_encounter(
  p_encounter_id uuid,
  p_idempotency_key varchar
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_encounter competition.user_demon_encounters%rowtype;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  if coalesce(length(trim(p_idempotency_key)), 0) = 0 or length(p_idempotency_key) > 150 then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  insert into platform.idempotency_records (
    user_id, idempotency_key, request_method, request_path, request_hash, expires_at
  )
  values (
    v_user_id,
    p_idempotency_key,
    'POST',
    format('/api/v1/encounters/%s/abandon', p_encounter_id),
    md5(p_encounter_id::text),
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
  into v_encounter
  from competition.user_demon_encounters
  where id = p_encounter_id and user_id = v_user_id
  for update;

  if not found then
    raise exception 'ENCOUNTER_NOT_FOUND';
  end if;

  if v_encounter.status <> 'active' then
    raise exception 'ENCOUNTER_NOT_ACTIVE';
  end if;

  update competition.user_demon_defense_assignments
  set status = 'cancelled'
  where encounter_id = v_encounter.id
    and status = 'assigned';

  update competition.user_demon_encounters
  set status = 'abandoned', ended_at = now(), version = version + 1
  where id = v_encounter.id
  returning * into v_encounter;

  insert into app.notifications (
    user_id, notification_type, title, body, action_url, payload
  )
  values (
    v_user_id,
    'demon_encounter_abandoned',
    'Encounter ended',
    'You can begin again with a new, concrete defense when you are ready.',
    '/battle',
    jsonb_build_object('encounterId', v_encounter.id)
  );

  insert into platform.outbox_events (aggregate_type, aggregate_id, event_type, payload)
  values (
    'demon_encounter',
    v_encounter.id,
    'demon_encounter.abandoned',
    jsonb_build_object('userId', v_user_id)
  );

  v_result := jsonb_build_object('replayed', false, 'encounter', to_jsonb(v_encounter));

  update platform.idempotency_records
  set response_status = 200, response_body = v_result, completed_at = now(), locked_until = null
  where user_id = v_user_id and idempotency_key = p_idempotency_key;

  return v_result;
end;
$$;

create or replace function api.record_spiritual_activity(
  p_activity_code varchar,
  p_occurred_at timestamptz,
  p_completed_at timestamptz default null,
  p_duration_seconds integer default null,
  p_quantity integer default 1,
  p_city_id uuid default null,
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
    quantity, verification_status, source, city_id, country_code,
    idempotency_key, metadata
  )
  values (
    v_user_id, v_activity_definition.code, p_occurred_at, p_completed_at,
    p_duration_seconds, p_quantity, 'self_reported', 'manual', p_city_id,
    upper(p_country_code)::char(2), p_idempotency_key, coalesce(p_metadata, '{}'::jsonb)
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
    v_new_progress := least(v_assignment.target_quantity, v_assignment.current_progress + v_activity.quantity);

    update competition.user_challenge_assignments
    set
      current_progress = v_new_progress,
      status = case when v_new_progress = v_assignment.target_quantity then 'completed' else 'active' end,
      completed_at = case when v_new_progress = v_assignment.target_quantity then now() else null end
    where id = v_assignment.id;

    insert into competition.challenge_progress_events (
      assignment_id, activity_id, increment_amount, previous_progress,
      resulting_progress, idempotency_key
    )
    values (
      v_assignment.id, v_activity.id, v_activity.quantity, v_assignment.current_progress,
      v_new_progress, 'activity-challenge:' || md5(p_idempotency_key || v_assignment.id::text)
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
      'award', v_points, v_point_rule.name, 'activity-points:' || md5(p_idempotency_key),
      jsonb_build_object('activityCode', v_activity.activity_code), v_activity.occurred_at
    );

    v_xp_result := api.award_user_xp(v_user_id, v_points, v_activity.occurred_at);
  end if;

  v_new_badges := api.refresh_badge_requirement_progress(v_user_id, v_activity.id);

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
      'activity-defense:' || md5(p_idempotency_key || v_battle_assignment_id::text)
    );

    v_battle_updates := jsonb_build_array(v_battle_result);
  end if;

  insert into platform.outbox_events (aggregate_type, aggregate_id, event_type, payload)
  values (
    'spiritual_activity',
    v_activity.id,
    'spiritual_activity.recorded',
    jsonb_build_object('userId', v_user_id, 'activityCode', v_activity.activity_code, 'quantity', v_activity.quantity)
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
  set response_status = 201, response_body = v_result, completed_at = now(), locked_until = null
  where user_id = v_user_id and idempotency_key = p_idempotency_key;

  return v_result;
end;
$$;

create or replace function api.claim_challenge_reward(
  p_assignment_id uuid,
  p_idempotency_key varchar
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_assignment competition.user_challenge_assignments%rowtype;
  v_definition competition.challenge_definitions%rowtype;
  v_existing_result jsonb;
  v_xp_result jsonb := '{}'::jsonb;
  v_badge_id uuid;
  v_badge_code varchar;
  v_user_badge_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  if coalesce(length(trim(p_idempotency_key)), 0) = 0 or length(p_idempotency_key) > 150 then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  insert into platform.idempotency_records (
    user_id, idempotency_key, request_method, request_path, request_hash, expires_at
  )
  values (
    v_user_id,
    p_idempotency_key,
    'POST',
    format('/api/v1/challenges/%s/claim', p_assignment_id),
    md5(p_assignment_id::text),
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
  into v_assignment
  from competition.user_challenge_assignments
  where id = p_assignment_id and user_id = v_user_id
  for update;

  if not found then
    raise exception 'CHALLENGE_NOT_FOUND';
  end if;

  if v_assignment.status <> 'completed' then
    raise exception 'CHALLENGE_NOT_COMPLETED';
  end if;

  if v_assignment.reward_claimed_at is not null then
    raise exception 'CHALLENGE_REWARD_ALREADY_CLAIMED';
  end if;

  select *
  into v_definition
  from competition.challenge_definitions
  where id = v_assignment.challenge_definition_id;

  update competition.user_challenge_assignments
  set reward_claimed_at = now()
  where id = v_assignment.id
  returning * into v_assignment;

  insert into competition.point_ledger (
    user_id, source_type, source_id, transaction_type, points, reason, idempotency_key, metadata
  )
  values (
    v_user_id, 'challenge_reward', v_assignment.id, 'award', v_definition.xp_reward,
    v_definition.title, 'challenge-reward:' || md5(p_idempotency_key),
    jsonb_build_object('challengeDefinitionId', v_definition.id)
  );

  v_xp_result := api.award_user_xp(v_user_id, v_definition.xp_reward, now());

  if v_definition.badge_reward_id is not null then
    select code into v_badge_code
    from competition.badge_definitions
    where id = v_definition.badge_reward_id;

    v_user_badge_id := null;
    insert into competition.user_badges (
      user_id, badge_id, source_type, source_id, sequence_number
    )
    select v_user_id, v_definition.badge_reward_id, 'challenge', v_assignment.id, 1
    where not exists (
      select 1 from competition.user_badges
      where user_id = v_user_id and badge_id = v_definition.badge_reward_id
    )
    returning id into v_user_badge_id;

    if v_user_badge_id is not null then
      v_badge_id := v_definition.badge_reward_id;
    end if;
  end if;

  insert into app.notifications (
    user_id, notification_type, title, body, action_url, payload
  )
  values (
    v_user_id,
    'challenge_reward_claimed',
    'Challenge reward claimed',
    'Your reward has been added to your progress.',
    '/progress',
    jsonb_build_object('assignmentId', v_assignment.id, 'xpAwarded', v_definition.xp_reward, 'badgeId', v_badge_id)
  );

  v_result := jsonb_build_object(
    'replayed', false,
    'assignment', to_jsonb(v_assignment),
    'xp', v_xp_result,
    'badge', case
      when v_badge_id is null then null
      else jsonb_build_object('id', v_badge_id, 'code', v_badge_code)
    end
  );

  update platform.idempotency_records
  set response_status = 200, response_body = v_result, completed_at = now(), locked_until = null
  where user_id = v_user_id and idempotency_key = p_idempotency_key;

  return v_result;
end;
$$;

revoke all on function api.initialize_user_virtues(uuid) from public, anon, authenticated;
revoke all on function api.award_user_xp(uuid, integer, timestamptz) from public, anon, authenticated;
revoke all on function api.refresh_badge_requirement_progress(uuid, uuid) from public, anon, authenticated;

revoke all on function api.start_demon_encounter(varchar, varchar) from public, anon;
revoke all on function api.complete_demon_defense(uuid, uuid, varchar) from public, anon;
revoke all on function api.abandon_demon_encounter(uuid, varchar) from public, anon;
revoke all on function api.record_spiritual_activity(varchar, timestamptz, timestamptz, integer, integer, uuid, varchar, varchar, jsonb) from public, anon;
revoke all on function api.claim_challenge_reward(uuid, varchar) from public, anon;

grant execute on function api.start_demon_encounter(varchar, varchar) to authenticated, service_role;
grant execute on function api.complete_demon_defense(uuid, uuid, varchar) to authenticated, service_role;
grant execute on function api.abandon_demon_encounter(uuid, varchar) to authenticated, service_role;
grant execute on function api.record_spiritual_activity(varchar, timestamptz, timestamptz, integer, integer, uuid, varchar, varchar, jsonb) to authenticated, service_role;
grant execute on function api.claim_challenge_reward(uuid, varchar) to authenticated, service_role;
