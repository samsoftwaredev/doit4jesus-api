-- Fictional spiritual-battle game domain.
--
-- Definitions are readable by authenticated players. All player state, virtue
-- changes, encounter HP, and rewards are server-managed: clients receive no
-- direct write privileges and must use a future transactional API routine.

create table competition.game_balance_config (
  id boolean primary key default true,
  schema_version varchar(20) not null,
  virtue_min smallint not null default 0,
  virtue_max smallint not null default 100,
  default_virtue_value smallint not null default 50,
  demon_default_max_hp smallint not null default 100,
  attack_penalty_min smallint not null default 2,
  attack_penalty_max smallint not null default 8,
  challenge_reward_min smallint not null default 3,
  challenge_reward_max smallint not null default 10,
  rules jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  check (id),
  check (virtue_min = 0),
  check (virtue_max = 100),
  check (default_virtue_value between virtue_min and virtue_max),
  check (demon_default_max_hp > 0),
  check (attack_penalty_min > 0 and attack_penalty_max >= attack_penalty_min),
  check (challenge_reward_min > 0 and challenge_reward_max >= challenge_reward_min)
);

create table competition.virtue_definitions (
  code varchar(50) primary key,
  name varchar(100) not null unique,
  description text not null,
  default_value smallint not null default 50,
  icon varchar(100) not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (default_value between 0 and 100)
);

create table competition.saint_definitions (
  id uuid primary key default gen_random_uuid(),
  code varchar(100) not null unique,
  name varchar(150) not null unique,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table competition.demon_definitions (
  id uuid primary key default gen_random_uuid(),
  code varchar(100) not null unique,
  name varchar(150) not null,
  title varchar(200) not null,
  description text not null,
  category varchar(50) not null,
  silly_personality text not null,
  saint_mentor_id uuid not null references competition.saint_definitions(id),
  saint_mentor_reason text not null,
  max_hp smallint not null default 100,
  safety_note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (category in ('DISTRACTION', 'SLOTH', 'ANGER', 'PRIDE', 'GLUTTONY', 'ENVY', 'FEAR', 'DISCOURAGEMENT', 'GOSSIP', 'GREED', 'CONFUSION', 'IMPURITY')),
  check (max_hp > 0)
);

create table competition.demon_virtue_affinities (
  demon_id uuid not null references competition.demon_definitions(id) on delete cascade,
  virtue_code varchar(50) not null references competition.virtue_definitions(code),
  affinity_type varchar(20) not null,
  created_at timestamptz not null default now(),
  primary key (demon_id, virtue_code),
  check (affinity_type in ('primary', 'secondary'))
);

create unique index demon_virtue_affinities_one_primary_idx
  on competition.demon_virtue_affinities (demon_id)
  where affinity_type = 'primary';

create table competition.demon_attacks (
  id uuid primary key default gen_random_uuid(),
  demon_id uuid not null references competition.demon_definitions(id) on delete cascade,
  code varchar(100) not null unique,
  name varchar(150) not null,
  description text not null,
  target_virtue_code varchar(50) not null references competition.virtue_definitions(code),
  virtue_decrease smallint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (virtue_decrease between 2 and 8)
);

create index idx_demon_attacks_demon on competition.demon_attacks (demon_id);

create table competition.demon_defenses (
  id uuid primary key default gen_random_uuid(),
  demon_id uuid not null references competition.demon_definitions(id) on delete cascade,
  code varchar(100) not null unique,
  name varchar(150) not null,
  challenge text not null,
  reward_virtue_code varchar(50) not null references competition.virtue_definitions(code),
  virtue_increase smallint not null,
  demon_damage smallint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (virtue_increase between 3 and 10),
  check (demon_damage > 0)
);

create index idx_demon_defenses_demon on competition.demon_defenses (demon_id);

create table competition.demon_defeat_rewards (
  demon_id uuid primary key references competition.demon_definitions(id) on delete cascade,
  virtue_code varchar(50) not null references competition.virtue_definitions(code),
  virtue_increase smallint not null,
  xp_reward integer not null,
  created_at timestamptz not null default now(),
  check (virtue_increase > 0),
  check (xp_reward > 0)
);

create table competition.badge_requirement_definitions (
  id uuid primary key default gen_random_uuid(),
  badge_id uuid not null references competition.badge_definitions(id) on delete cascade,
  requirement_type varchar(100) not null,
  required_value integer not null,
  description text not null,
  rules jsonb not null default '{}'::jsonb,
  display_order smallint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (badge_id, display_order),
  check (required_value > 0),
  check (display_order > 0)
);

create index idx_badge_requirement_definitions_badge
  on competition.badge_requirement_definitions (badge_id, display_order);

create table competition.user_virtues (
  user_id uuid not null references app.users(id) on delete cascade,
  virtue_code varchar(50) not null references competition.virtue_definitions(code),
  current_value smallint not null default 50,
  version bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (user_id, virtue_code),
  check (current_value between 0 and 100),
  check (version > 0)
);

create index idx_user_virtues_virtue on competition.user_virtues (virtue_code);

create table competition.user_demon_encounters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app.users(id) on delete cascade,
  demon_id uuid not null references competition.demon_definitions(id),
  status varchar(20) not null default 'active',
  max_hp smallint not null,
  current_hp smallint not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  defeated_at timestamptz,
  version bigint not null default 1,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('active', 'defeated', 'abandoned', 'expired')),
  check (max_hp > 0),
  check (current_hp between 0 and max_hp),
  check (version > 0),
  check ((status = 'active' and ended_at is null and defeated_at is null) or status <> 'active'),
  check ((status = 'defeated' and current_hp = 0 and defeated_at is not null) or status <> 'defeated')
);

create unique index user_demon_encounters_one_active_idx
  on competition.user_demon_encounters (user_id, demon_id)
  where status = 'active';

create index idx_user_demon_encounters_user_status
  on competition.user_demon_encounters (user_id, status, started_at desc);

create table competition.user_demon_defense_assignments (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid not null references competition.user_demon_encounters(id) on delete cascade,
  defense_id uuid not null references competition.demon_defenses(id),
  assignment_sequence integer not null default 1,
  status varchar(20) not null default 'assigned',
  assigned_at timestamptz not null default now(),
  expires_at timestamptz,
  completed_at timestamptz,
  challenge_assignment_id uuid references competition.user_challenge_assignments(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (encounter_id, defense_id, assignment_sequence),
  check (assignment_sequence > 0),
  check (status in ('assigned', 'completed', 'expired', 'cancelled')),
  check (expires_at is null or expires_at > assigned_at),
  check ((status = 'completed' and completed_at is not null) or status <> 'completed')
);

create index idx_user_demon_defense_assignments_encounter_status
  on competition.user_demon_defense_assignments (encounter_id, status, assigned_at desc);

create table competition.virtue_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app.users(id) on delete cascade,
  virtue_code varchar(50) not null references competition.virtue_definitions(code),
  encounter_id uuid references competition.user_demon_encounters(id) on delete set null,
  source_type varchar(50) not null,
  source_id uuid,
  previous_value smallint not null,
  delta smallint not null,
  resulting_value smallint not null,
  idempotency_key varchar(150) not null unique,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (source_type in ('demon_attack', 'demon_defense', 'demon_defeat', 'admin_adjustment', 'system')),
  check (previous_value between 0 and 100),
  check (delta <> 0),
  check (resulting_value between 0 and 100),
  check (resulting_value = previous_value + delta)
);

create index idx_virtue_events_user_occurred
  on competition.virtue_events (user_id, occurred_at desc);
create index idx_virtue_events_encounter
  on competition.virtue_events (encounter_id, occurred_at desc);

create table competition.demon_battle_events (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid not null references competition.user_demon_encounters(id) on delete cascade,
  event_type varchar(30) not null,
  attack_id uuid references competition.demon_attacks(id),
  defense_assignment_id uuid references competition.user_demon_defense_assignments(id),
  virtue_event_id uuid not null references competition.virtue_events(id),
  previous_hp smallint not null,
  demon_damage smallint not null default 0,
  resulting_hp smallint not null,
  idempotency_key varchar(150) not null unique,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (event_type in ('attack', 'defense_completed', 'demon_defeated')),
  check (previous_hp >= 0),
  check (demon_damage >= 0),
  check (resulting_hp >= 0),
  check (resulting_hp = previous_hp - demon_damage),
  check (
    (event_type = 'attack' and attack_id is not null and defense_assignment_id is null)
    or (event_type = 'defense_completed' and attack_id is null and defense_assignment_id is not null)
    or (event_type = 'demon_defeated' and attack_id is null and defense_assignment_id is null)
  )
);

create index idx_demon_battle_events_encounter_occurred
  on competition.demon_battle_events (encounter_id, occurred_at desc);

create trigger trg_game_balance_config_updated_at
before update on competition.game_balance_config
for each row execute function platform.set_updated_at();

create trigger trg_virtue_definitions_updated_at
before update on competition.virtue_definitions
for each row execute function platform.set_updated_at();

create trigger trg_saint_definitions_updated_at
before update on competition.saint_definitions
for each row execute function platform.set_updated_at();

create trigger trg_demon_definitions_updated_at
before update on competition.demon_definitions
for each row execute function platform.set_updated_at();

create trigger trg_demon_attacks_updated_at
before update on competition.demon_attacks
for each row execute function platform.set_updated_at();

create trigger trg_demon_defenses_updated_at
before update on competition.demon_defenses
for each row execute function platform.set_updated_at();

create trigger trg_badge_requirement_definitions_updated_at
before update on competition.badge_requirement_definitions
for each row execute function platform.set_updated_at();

create trigger trg_user_virtues_updated_at
before update on competition.user_virtues
for each row execute function platform.set_updated_at();

create trigger trg_user_demon_encounters_updated_at
before update on competition.user_demon_encounters
for each row execute function platform.set_updated_at();

create trigger trg_user_demon_defense_assignments_updated_at
before update on competition.user_demon_defense_assignments
for each row execute function platform.set_updated_at();

alter table competition.game_balance_config enable row level security;
alter table competition.virtue_definitions enable row level security;
alter table competition.saint_definitions enable row level security;
alter table competition.demon_definitions enable row level security;
alter table competition.demon_virtue_affinities enable row level security;
alter table competition.demon_attacks enable row level security;
alter table competition.demon_defenses enable row level security;
alter table competition.demon_defeat_rewards enable row level security;
alter table competition.badge_requirement_definitions enable row level security;
alter table competition.user_virtues enable row level security;
alter table competition.user_demon_encounters enable row level security;
alter table competition.user_demon_defense_assignments enable row level security;
alter table competition.virtue_events enable row level security;
alter table competition.demon_battle_events enable row level security;

revoke all privileges on
  competition.game_balance_config,
  competition.virtue_definitions,
  competition.saint_definitions,
  competition.demon_definitions,
  competition.demon_virtue_affinities,
  competition.demon_attacks,
  competition.demon_defenses,
  competition.demon_defeat_rewards,
  competition.badge_requirement_definitions,
  competition.user_virtues,
  competition.user_demon_encounters,
  competition.user_demon_defense_assignments,
  competition.virtue_events,
  competition.demon_battle_events
from anon, authenticated;

grant select on
  competition.game_balance_config,
  competition.virtue_definitions,
  competition.saint_definitions,
  competition.demon_definitions,
  competition.demon_virtue_affinities,
  competition.demon_attacks,
  competition.demon_defenses,
  competition.demon_defeat_rewards,
  competition.badge_requirement_definitions,
  competition.user_virtues,
  competition.user_demon_encounters,
  competition.user_demon_defense_assignments,
  competition.virtue_events,
  competition.demon_battle_events
to authenticated;

grant all privileges on
  competition.game_balance_config,
  competition.virtue_definitions,
  competition.saint_definitions,
  competition.demon_definitions,
  competition.demon_virtue_affinities,
  competition.demon_attacks,
  competition.demon_defenses,
  competition.demon_defeat_rewards,
  competition.badge_requirement_definitions,
  competition.user_virtues,
  competition.user_demon_encounters,
  competition.user_demon_defense_assignments,
  competition.virtue_events,
  competition.demon_battle_events
to service_role;

create policy game_balance_config_select_authenticated
on competition.game_balance_config for select to authenticated using (true);

create policy virtue_definitions_select_active_authenticated
on competition.virtue_definitions for select to authenticated using (is_active);

create policy saint_definitions_select_active_authenticated
on competition.saint_definitions for select to authenticated using (is_active);

create policy demon_definitions_select_active_authenticated
on competition.demon_definitions for select to authenticated using (is_active);

create policy demon_virtue_affinities_select_authenticated
on competition.demon_virtue_affinities for select to authenticated using (true);

create policy demon_attacks_select_authenticated
on competition.demon_attacks for select to authenticated using (true);

create policy demon_defenses_select_authenticated
on competition.demon_defenses for select to authenticated using (true);

create policy demon_defeat_rewards_select_authenticated
on competition.demon_defeat_rewards for select to authenticated using (true);

create policy badge_requirement_definitions_select_authenticated
on competition.badge_requirement_definitions for select to authenticated using (true);

create policy user_virtues_select_own
on competition.user_virtues for select to authenticated
using ((select auth.uid()) = user_id);

create policy user_demon_encounters_select_own
on competition.user_demon_encounters for select to authenticated
using ((select auth.uid()) = user_id);

create policy user_demon_defense_assignments_select_own
on competition.user_demon_defense_assignments for select to authenticated
using (
  exists (
    select 1
    from competition.user_demon_encounters encounter
    where encounter.id = user_demon_defense_assignments.encounter_id
      and encounter.user_id = (select auth.uid())
  )
);

create policy virtue_events_select_own
on competition.virtue_events for select to authenticated
using ((select auth.uid()) = user_id);

create policy demon_battle_events_select_own
on competition.demon_battle_events for select to authenticated
using (
  exists (
    select 1
    from competition.user_demon_encounters encounter
    where encounter.id = demon_battle_events.encounter_id
      and encounter.user_id = (select auth.uid())
  )
);
