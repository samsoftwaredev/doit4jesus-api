
  create table "competition"."challenge_definitions" (
    "id" uuid not null default gen_random_uuid(),
    "code" character varying(100) not null,
    "title" character varying(150) not null,
    "description" text,
    "challenge_type" text not null,
    "activity_code" character varying(50),
    "target_quantity" integer not null default 1,
    "xp_reward" integer not null default 0,
    "badge_reward_id" uuid,
    "difficulty" text not null default 'normal'::text,
    "assignment_weight" integer not null default 100,
    "rules" jsonb not null default '{}'::jsonb,
    "icon_url" text,
    "starts_at" timestamp with time zone,
    "ends_at" timestamp with time zone,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."challenge_definitions" enable row level security;


  create table "competition"."level_definitions" (
    "level_number" integer not null,
    "code" character varying(100) not null,
    "name" character varying(100) not null,
    "description" text,
    "minimum_total_xp" bigint not null,
    "icon_url" text,
    "image_url" text,
    "reward_type" character varying(50),
    "reward_reference_id" uuid,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );


alter table "competition"."level_definitions" enable row level security;


  create table "competition"."point_ledger" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "point_rule_id" uuid,
    "activity_id" uuid,
    "source_type" character varying(50) not null,
    "source_id" uuid,
    "transaction_type" text not null,
    "points" integer not null,
    "reason" character varying(150) not null,
    "idempotency_key" character varying(150) not null,
    "metadata" jsonb not null default '{}'::jsonb,
    "occurred_at" timestamp with time zone not null default now(),
    "created_at" timestamp with time zone not null default now()
      );


alter table "competition"."point_ledger" enable row level security;


  create table "competition"."point_rules" (
    "id" uuid not null default gen_random_uuid(),
    "code" character varying(100) not null,
    "activity_code" character varying(50),
    "name" character varying(150) not null,
    "description" text,
    "points" integer not null,
    "daily_limit" integer,
    "weekly_limit" integer,
    "effective_from" timestamp with time zone not null default now(),
    "effective_until" timestamp with time zone,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."point_rules" enable row level security;


  create table "competition"."spiritual_activities" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "activity_code" character varying(50) not null,
    "occurred_at" timestamp with time zone not null,
    "completed_at" timestamp with time zone,
    "duration_seconds" integer,
    "quantity" integer not null default 1,
    "verification_status" text not null default 'self_reported'::text,
    "source" text not null default 'manual'::text,
    "city_id" uuid,
    "country_code" character(2),
    "idempotency_key" character varying(150),
    "metadata" jsonb not null default '{}'::jsonb,
    "created_at" timestamp with time zone not null default now()
      );


alter table "competition"."spiritual_activities" enable row level security;


  create table "competition"."user_progress" (
    "user_id" uuid not null,
    "total_xp" bigint not null default 0,
    "current_level" integer not null default 1,
    "weekly_points" bigint not null default 0,
    "yearly_points" bigint not null default 0,
    "lifetime_points" bigint not null default 0,
    "last_activity_at" timestamp with time zone,
    "version" bigint not null default 1,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."user_progress" enable row level security;

CREATE UNIQUE INDEX challenge_definitions_code_key ON competition.challenge_definitions USING btree (code);

CREATE UNIQUE INDEX challenge_definitions_pkey ON competition.challenge_definitions USING btree (id);

CREATE INDEX idx_challenge_definitions_active_type ON competition.challenge_definitions USING btree (challenge_type, is_active);

CREATE INDEX idx_challenge_definitions_rules ON competition.challenge_definitions USING gin (rules);

CREATE INDEX idx_point_ledger_activity ON competition.point_ledger USING btree (activity_id);

CREATE INDEX idx_point_ledger_source ON competition.point_ledger USING btree (source_type, source_id);

CREATE INDEX idx_point_ledger_user_date ON competition.point_ledger USING btree (user_id, occurred_at DESC);

CREATE INDEX idx_point_rules_activity ON competition.point_rules USING btree (activity_code) WHERE (is_active = true);

CREATE INDEX idx_spiritual_activities_country_date ON competition.spiritual_activities USING btree (country_code, occurred_at DESC);

CREATE INDEX idx_spiritual_activities_metadata ON competition.spiritual_activities USING gin (metadata);

CREATE INDEX idx_spiritual_activities_type_date ON competition.spiritual_activities USING btree (activity_code, occurred_at DESC);

CREATE INDEX idx_spiritual_activities_user_occurred ON competition.spiritual_activities USING btree (user_id, occurred_at DESC);

CREATE INDEX idx_user_progress_total_xp ON competition.user_progress USING btree (total_xp DESC);

CREATE INDEX idx_user_progress_weekly ON competition.user_progress USING btree (weekly_points DESC);

CREATE INDEX idx_user_progress_yearly ON competition.user_progress USING btree (yearly_points DESC);

CREATE UNIQUE INDEX level_definitions_code_key ON competition.level_definitions USING btree (code);

CREATE UNIQUE INDEX level_definitions_minimum_total_xp_key ON competition.level_definitions USING btree (minimum_total_xp);

CREATE UNIQUE INDEX level_definitions_pkey ON competition.level_definitions USING btree (level_number);

CREATE UNIQUE INDEX point_ledger_idempotency_key_key ON competition.point_ledger USING btree (idempotency_key);

CREATE UNIQUE INDEX point_ledger_pkey ON competition.point_ledger USING btree (id);

CREATE UNIQUE INDEX point_rules_code_key ON competition.point_rules USING btree (code);

CREATE UNIQUE INDEX point_rules_pkey ON competition.point_rules USING btree (id);

CREATE UNIQUE INDEX spiritual_activities_pkey ON competition.spiritual_activities USING btree (id);

CREATE UNIQUE INDEX spiritual_activities_user_id_idempotency_key_key ON competition.spiritual_activities USING btree (user_id, idempotency_key);

CREATE UNIQUE INDEX user_progress_pkey ON competition.user_progress USING btree (user_id);

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_pkey" PRIMARY KEY using index "challenge_definitions_pkey";

alter table "competition"."level_definitions" add constraint "level_definitions_pkey" PRIMARY KEY using index "level_definitions_pkey";

alter table "competition"."point_ledger" add constraint "point_ledger_pkey" PRIMARY KEY using index "point_ledger_pkey";

alter table "competition"."point_rules" add constraint "point_rules_pkey" PRIMARY KEY using index "point_rules_pkey";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_pkey" PRIMARY KEY using index "spiritual_activities_pkey";

alter table "competition"."user_progress" add constraint "user_progress_pkey" PRIMARY KEY using index "user_progress_pkey";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_activity_code_fkey" FOREIGN KEY (activity_code) REFERENCES competition.activity_definitions(code) not valid;

alter table "competition"."challenge_definitions" validate constraint "challenge_definitions_activity_code_fkey";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_assignment_weight_check" CHECK ((assignment_weight >= 0)) not valid;

alter table "competition"."challenge_definitions" validate constraint "challenge_definitions_assignment_weight_check";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_challenge_type_check" CHECK ((challenge_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'special'::text, 'seasonal'::text]))) not valid;

alter table "competition"."challenge_definitions" validate constraint "challenge_definitions_challenge_type_check";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_check" CHECK (((ends_at IS NULL) OR (starts_at IS NULL) OR (ends_at > starts_at))) not valid;

alter table "competition"."challenge_definitions" validate constraint "challenge_definitions_check";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_code_key" UNIQUE using index "challenge_definitions_code_key";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_difficulty_check" CHECK ((difficulty = ANY (ARRAY['easy'::text, 'normal'::text, 'hard'::text, 'heroic'::text]))) not valid;

alter table "competition"."challenge_definitions" validate constraint "challenge_definitions_difficulty_check";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_target_quantity_check" CHECK ((target_quantity > 0)) not valid;

alter table "competition"."challenge_definitions" validate constraint "challenge_definitions_target_quantity_check";

alter table "competition"."challenge_definitions" add constraint "challenge_definitions_xp_reward_check" CHECK ((xp_reward >= 0)) not valid;

alter table "competition"."challenge_definitions" validate constraint "challenge_definitions_xp_reward_check";

alter table "competition"."level_definitions" add constraint "level_definitions_code_key" UNIQUE using index "level_definitions_code_key";

alter table "competition"."level_definitions" add constraint "level_definitions_level_number_check" CHECK ((level_number > 0)) not valid;

alter table "competition"."level_definitions" validate constraint "level_definitions_level_number_check";

alter table "competition"."level_definitions" add constraint "level_definitions_minimum_total_xp_check" CHECK ((minimum_total_xp >= 0)) not valid;

alter table "competition"."level_definitions" validate constraint "level_definitions_minimum_total_xp_check";

alter table "competition"."level_definitions" add constraint "level_definitions_minimum_total_xp_key" UNIQUE using index "level_definitions_minimum_total_xp_key";

alter table "competition"."point_ledger" add constraint "point_ledger_activity_id_fkey" FOREIGN KEY (activity_id) REFERENCES competition.spiritual_activities(id) not valid;

alter table "competition"."point_ledger" validate constraint "point_ledger_activity_id_fkey";

alter table "competition"."point_ledger" add constraint "point_ledger_idempotency_key_key" UNIQUE using index "point_ledger_idempotency_key_key";

alter table "competition"."point_ledger" add constraint "point_ledger_point_rule_id_fkey" FOREIGN KEY (point_rule_id) REFERENCES competition.point_rules(id) not valid;

alter table "competition"."point_ledger" validate constraint "point_ledger_point_rule_id_fkey";

alter table "competition"."point_ledger" add constraint "point_ledger_points_check" CHECK ((points <> 0)) not valid;

alter table "competition"."point_ledger" validate constraint "point_ledger_points_check";

alter table "competition"."point_ledger" add constraint "point_ledger_transaction_type_check" CHECK ((transaction_type = ANY (ARRAY['award'::text, 'reversal'::text, 'adjustment'::text]))) not valid;

alter table "competition"."point_ledger" validate constraint "point_ledger_transaction_type_check";

alter table "competition"."point_ledger" add constraint "point_ledger_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."point_ledger" validate constraint "point_ledger_user_id_fkey";

alter table "competition"."point_rules" add constraint "point_rules_activity_code_fkey" FOREIGN KEY (activity_code) REFERENCES competition.activity_definitions(code) not valid;

alter table "competition"."point_rules" validate constraint "point_rules_activity_code_fkey";

alter table "competition"."point_rules" add constraint "point_rules_check" CHECK (((effective_until IS NULL) OR (effective_until > effective_from))) not valid;

alter table "competition"."point_rules" validate constraint "point_rules_check";

alter table "competition"."point_rules" add constraint "point_rules_code_key" UNIQUE using index "point_rules_code_key";

alter table "competition"."point_rules" add constraint "point_rules_daily_limit_check" CHECK (((daily_limit IS NULL) OR (daily_limit > 0))) not valid;

alter table "competition"."point_rules" validate constraint "point_rules_daily_limit_check";

alter table "competition"."point_rules" add constraint "point_rules_points_check" CHECK ((points >= 0)) not valid;

alter table "competition"."point_rules" validate constraint "point_rules_points_check";

alter table "competition"."point_rules" add constraint "point_rules_weekly_limit_check" CHECK (((weekly_limit IS NULL) OR (weekly_limit > 0))) not valid;

alter table "competition"."point_rules" validate constraint "point_rules_weekly_limit_check";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_activity_code_fkey" FOREIGN KEY (activity_code) REFERENCES competition.activity_definitions(code) not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_activity_code_fkey";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_city_id_fkey" FOREIGN KEY (city_id) REFERENCES app.cities(id) not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_city_id_fkey";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_country_code_fkey" FOREIGN KEY (country_code) REFERENCES app.countries(code) not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_country_code_fkey";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_duration_seconds_check" CHECK (((duration_seconds IS NULL) OR (duration_seconds >= 0))) not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_duration_seconds_check";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_quantity_check" CHECK ((quantity > 0)) not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_quantity_check";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_source_check" CHECK ((source = ANY (ARRAY['manual'::text, 'challenge'::text, 'live_prayer'::text, 'import'::text, 'admin'::text, 'system'::text]))) not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_source_check";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_user_id_fkey";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_user_id_idempotency_key_key" UNIQUE using index "spiritual_activities_user_id_idempotency_key_key";

alter table "competition"."spiritual_activities" add constraint "spiritual_activities_verification_status_check" CHECK ((verification_status = ANY (ARRAY['self_reported'::text, 'verified'::text, 'rejected'::text]))) not valid;

alter table "competition"."spiritual_activities" validate constraint "spiritual_activities_verification_status_check";

alter table "competition"."user_progress" add constraint "user_progress_current_level_fkey" FOREIGN KEY (current_level) REFERENCES competition.level_definitions(level_number) not valid;

alter table "competition"."user_progress" validate constraint "user_progress_current_level_fkey";

alter table "competition"."user_progress" add constraint "user_progress_lifetime_points_check" CHECK ((lifetime_points >= 0)) not valid;

alter table "competition"."user_progress" validate constraint "user_progress_lifetime_points_check";

alter table "competition"."user_progress" add constraint "user_progress_total_xp_check" CHECK ((total_xp >= 0)) not valid;

alter table "competition"."user_progress" validate constraint "user_progress_total_xp_check";

alter table "competition"."user_progress" add constraint "user_progress_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."user_progress" validate constraint "user_progress_user_id_fkey";

alter table "competition"."user_progress" add constraint "user_progress_weekly_points_check" CHECK ((weekly_points >= 0)) not valid;

alter table "competition"."user_progress" validate constraint "user_progress_weekly_points_check";

alter table "competition"."user_progress" add constraint "user_progress_yearly_points_check" CHECK ((yearly_points >= 0)) not valid;

alter table "competition"."user_progress" validate constraint "user_progress_yearly_points_check";

CREATE TRIGGER trg_challenge_definitions_updated_at BEFORE UPDATE ON competition.challenge_definitions FOR EACH ROW EXECUTE FUNCTION platform.set_updated_at();

CREATE TRIGGER trg_point_rules_updated_at BEFORE UPDATE ON competition.point_rules FOR EACH ROW EXECUTE FUNCTION platform.set_updated_at();


