
  create table "competition"."badge_definitions" (
    "id" uuid not null default gen_random_uuid(),
    "code" character varying(100) not null,
    "name" character varying(120) not null,
    "description" text,
    "category" text not null,
    "rarity" text not null default 'common'::text,
    "icon_url" text not null,
    "locked_icon_url" text,
    "requirement_type" character varying(100),
    "requirement_value" integer,
    "rules" jsonb not null default '{}'::jsonb,
    "points_reward" integer not null default 0,
    "is_repeatable" boolean not null default false,
    "is_shareable" boolean not null default true,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."badge_definitions" enable row level security;


  create table "competition"."badge_shares" (
    "id" uuid not null default gen_random_uuid(),
    "user_badge_id" uuid not null,
    "share_token" character varying(120) not null,
    "platform" text,
    "visibility" text not null default 'public'::text,
    "expires_at" timestamp with time zone,
    "revoked_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now()
      );


alter table "competition"."badge_shares" enable row level security;


  create table "competition"."challenge_progress_events" (
    "id" uuid not null default gen_random_uuid(),
    "assignment_id" uuid not null,
    "activity_id" uuid,
    "increment_amount" integer not null,
    "previous_progress" integer not null,
    "resulting_progress" integer not null,
    "idempotency_key" character varying(150) not null,
    "occurred_at" timestamp with time zone not null default now()
      );


alter table "competition"."challenge_progress_events" enable row level security;


  create table "competition"."leaderboard_entries" (
    "period_id" uuid not null,
    "user_id" uuid not null,
    "scope_type" text not null,
    "scope_reference" character varying(150) not null default 'global'::character varying,
    "points" bigint not null default 0,
    "rank" integer,
    "rosaries_count" integer not null default 0,
    "scripture_readings_count" integer not null default 0,
    "prayers_count" integer not null default 0,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."leaderboard_entries" enable row level security;


  create table "competition"."leaderboard_periods" (
    "id" uuid not null default gen_random_uuid(),
    "period_type" text not null,
    "code" character varying(100) not null,
    "name" character varying(150) not null,
    "starts_at" timestamp with time zone not null,
    "ends_at" timestamp with time zone not null,
    "status" text not null default 'scheduled'::text,
    "finalized_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now()
      );


alter table "competition"."leaderboard_periods" enable row level security;


  create table "competition"."user_badge_progress" (
    "user_id" uuid not null,
    "badge_id" uuid not null,
    "current_value" integer not null default 0,
    "required_value" integer not null,
    "progress_percentage" numeric(5,2) generated always as (LEAST(100.00, (((current_value)::numeric / (required_value)::numeric) * (100)::numeric))) stored,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."user_badge_progress" enable row level security;


  create table "competition"."user_badges" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "badge_id" uuid not null,
    "earned_at" timestamp with time zone not null default now(),
    "source_type" character varying(50),
    "source_id" uuid,
    "sequence_number" integer not null default 1,
    "is_featured" boolean not null default false,
    "metadata" jsonb not null default '{}'::jsonb
      );


alter table "competition"."user_badges" enable row level security;


  create table "competition"."user_challenge_assignments" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "challenge_definition_id" uuid not null,
    "assignment_date" date not null,
    "starts_at" timestamp with time zone not null,
    "expires_at" timestamp with time zone not null,
    "target_quantity" integer not null,
    "current_progress" integer not null default 0,
    "status" text not null default 'active'::text,
    "completed_at" timestamp with time zone,
    "reward_claimed_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."user_challenge_assignments" enable row level security;


  create table "competition"."user_metric_snapshots" (
    "user_id" uuid not null,
    "snapshot_date" date not null,
    "rosaries_count" integer not null default 0,
    "scripture_readings_count" integer not null default 0,
    "prayer_sessions_count" integer not null default 0,
    "service_acts_count" integer not null default 0,
    "points_earned" integer not null default 0,
    "prayer_duration_seconds" bigint not null default 0,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."user_metric_snapshots" enable row level security;


  create table "platform"."idempotency_records" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid,
    "idempotency_key" character varying(150) not null,
    "request_method" character varying(10) not null,
    "request_path" text not null,
    "request_hash" character varying(128) not null,
    "response_status" integer,
    "response_body" jsonb,
    "locked_until" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "expires_at" timestamp with time zone not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "platform"."idempotency_records" enable row level security;


  create table "platform"."outbox_events" (
    "id" uuid not null default gen_random_uuid(),
    "aggregate_type" character varying(100) not null,
    "aggregate_id" uuid not null,
    "event_type" character varying(150) not null,
    "payload" jsonb not null,
    "occurred_at" timestamp with time zone not null default now(),
    "processing_status" text not null default 'pending'::text,
    "attempt_count" integer not null default 0,
    "available_at" timestamp with time zone not null default now(),
    "locked_at" timestamp with time zone,
    "processed_at" timestamp with time zone,
    "last_error" text
      );


alter table "platform"."outbox_events" enable row level security;


  create table "prayer"."city_daily_aggregates" (
    "city_id" uuid not null,
    "aggregate_date" date not null,
    "total_prayers" bigint not null default 0,
    "unique_users" bigint not null default 0,
    "rosaries" bigint not null default 0,
    "prayer_duration_seconds" bigint not null default 0,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "prayer"."city_daily_aggregates" enable row level security;


  create table "prayer"."country_daily_aggregates" (
    "country_code" character(2) not null,
    "aggregate_date" date not null,
    "total_prayers" bigint not null default 0,
    "unique_users" bigint not null default 0,
    "rosaries" bigint not null default 0,
    "prayer_duration_seconds" bigint not null default 0,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "prayer"."country_daily_aggregates" enable row level security;


  create table "prayer"."map_markers" (
    "id" uuid not null default gen_random_uuid(),
    "aggregation_level" text not null,
    "location_reference" character varying(150) not null,
    "name" character varying(150) not null,
    "country_code" character(2) not null,
    "latitude" numeric(9,6) not null,
    "longitude" numeric(9,6) not null,
    "prayer_count" bigint not null default 0,
    "unique_users" bigint not null default 0,
    "intensity" numeric(5,4) not null default 0,
    "period_start" timestamp with time zone not null,
    "period_end" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "prayer"."map_markers" enable row level security;


  create table "prayer"."prayer_events" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "activity_id" uuid,
    "prayer_type" text not null,
    "quantity" integer not null default 1,
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone not null,
    "city_id" uuid,
    "country_code" character(2) not null,
    "visibility" text not null default 'aggregated'::text,
    "metadata" jsonb not null default '{}'::jsonb,
    "created_at" timestamp with time zone not null default now()
      );


alter table "prayer"."prayer_events" enable row level security;

CREATE UNIQUE INDEX badge_definitions_code_key ON competition.badge_definitions USING btree (code);

CREATE UNIQUE INDEX badge_definitions_pkey ON competition.badge_definitions USING btree (id);

CREATE UNIQUE INDEX badge_shares_pkey ON competition.badge_shares USING btree (id);

CREATE UNIQUE INDEX badge_shares_share_token_key ON competition.badge_shares USING btree (share_token);

CREATE UNIQUE INDEX challenge_progress_events_idempotency_key_key ON competition.challenge_progress_events USING btree (idempotency_key);

CREATE UNIQUE INDEX challenge_progress_events_pkey ON competition.challenge_progress_events USING btree (id);

CREATE INDEX idx_badge_definitions_category ON competition.badge_definitions USING btree (category) WHERE (is_active = true);

CREATE INDEX idx_badge_definitions_rules ON competition.badge_definitions USING gin (rules);

CREATE INDEX idx_badge_shares_active_token ON competition.badge_shares USING btree (share_token) WHERE (revoked_at IS NULL);

CREATE INDEX idx_challenge_assignments_expiration ON competition.user_challenge_assignments USING btree (expires_at) WHERE (status = 'active'::text);

CREATE INDEX idx_challenge_assignments_user_status ON competition.user_challenge_assignments USING btree (user_id, status, assignment_date DESC);

CREATE INDEX idx_challenge_progress_assignment ON competition.challenge_progress_events USING btree (assignment_id, occurred_at DESC);

CREATE INDEX idx_leaderboard_entries_rank ON competition.leaderboard_entries USING btree (period_id, scope_type, scope_reference, rank);

CREATE INDEX idx_leaderboard_entries_ranking ON competition.leaderboard_entries USING btree (period_id, scope_type, scope_reference, points DESC, user_id);

CREATE INDEX idx_leaderboard_periods_type_status ON competition.leaderboard_periods USING btree (period_type, status, starts_at DESC);

CREATE INDEX idx_metric_snapshots_date ON competition.user_metric_snapshots USING btree (snapshot_date DESC);

CREATE INDEX idx_user_badges_featured ON competition.user_badges USING btree (user_id) WHERE (is_featured = true);

CREATE INDEX idx_user_badges_user_earned ON competition.user_badges USING btree (user_id, earned_at DESC);

CREATE UNIQUE INDEX leaderboard_entries_pkey ON competition.leaderboard_entries USING btree (period_id, user_id, scope_type, scope_reference);

CREATE UNIQUE INDEX leaderboard_periods_code_key ON competition.leaderboard_periods USING btree (code);

CREATE UNIQUE INDEX leaderboard_periods_pkey ON competition.leaderboard_periods USING btree (id);

CREATE UNIQUE INDEX user_badge_progress_pkey ON competition.user_badge_progress USING btree (user_id, badge_id);

CREATE UNIQUE INDEX user_badges_pkey ON competition.user_badges USING btree (id);

CREATE UNIQUE INDEX user_badges_user_id_badge_id_sequence_number_key ON competition.user_badges USING btree (user_id, badge_id, sequence_number);

CREATE UNIQUE INDEX user_challenge_assignments_pkey ON competition.user_challenge_assignments USING btree (id);

CREATE UNIQUE INDEX user_challenge_assignments_user_id_challenge_definition_id__key ON competition.user_challenge_assignments USING btree (user_id, challenge_definition_id, assignment_date);

CREATE UNIQUE INDEX user_metric_snapshots_pkey ON competition.user_metric_snapshots USING btree (user_id, snapshot_date);

CREATE UNIQUE INDEX idempotency_records_pkey ON platform.idempotency_records USING btree (id);

CREATE UNIQUE INDEX idempotency_records_user_id_idempotency_key_key ON platform.idempotency_records USING btree (user_id, idempotency_key);

CREATE INDEX idx_idempotency_expiration ON platform.idempotency_records USING btree (expires_at);

CREATE INDEX idx_outbox_pending ON platform.outbox_events USING btree (available_at, occurred_at) WHERE (processing_status = ANY (ARRAY['pending'::text, 'failed'::text]));

CREATE UNIQUE INDEX outbox_events_pkey ON platform.outbox_events USING btree (id);

CREATE UNIQUE INDEX city_daily_aggregates_pkey ON prayer.city_daily_aggregates USING btree (city_id, aggregate_date);

CREATE UNIQUE INDEX country_daily_aggregates_pkey ON prayer.country_daily_aggregates USING btree (country_code, aggregate_date);

CREATE INDEX idx_city_aggregates_date_prayers ON prayer.city_daily_aggregates USING btree (aggregate_date, total_prayers DESC);

CREATE INDEX idx_map_markers_period ON prayer.map_markers USING btree (aggregation_level, period_start, period_end);

CREATE INDEX idx_prayer_events_city_completed ON prayer.prayer_events USING btree (city_id, completed_at DESC) WHERE (city_id IS NOT NULL);

CREATE INDEX idx_prayer_events_country_completed ON prayer.prayer_events USING btree (country_code, completed_at DESC);

CREATE INDEX idx_prayer_events_type_completed ON prayer.prayer_events USING btree (prayer_type, completed_at DESC);

CREATE UNIQUE INDEX map_markers_aggregation_level_location_reference_period_sta_key ON prayer.map_markers USING btree (aggregation_level, location_reference, period_start, period_end);

CREATE UNIQUE INDEX map_markers_pkey ON prayer.map_markers USING btree (id);

CREATE UNIQUE INDEX prayer_events_pkey ON prayer.prayer_events USING btree (id);

alter table "competition"."badge_definitions" add constraint "badge_definitions_pkey" PRIMARY KEY using index "badge_definitions_pkey";

alter table "competition"."badge_shares" add constraint "badge_shares_pkey" PRIMARY KEY using index "badge_shares_pkey";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_pkey" PRIMARY KEY using index "challenge_progress_events_pkey";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_pkey" PRIMARY KEY using index "leaderboard_entries_pkey";

alter table "competition"."leaderboard_periods" add constraint "leaderboard_periods_pkey" PRIMARY KEY using index "leaderboard_periods_pkey";

alter table "competition"."user_badge_progress" add constraint "user_badge_progress_pkey" PRIMARY KEY using index "user_badge_progress_pkey";

alter table "competition"."user_badges" add constraint "user_badges_pkey" PRIMARY KEY using index "user_badges_pkey";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_pkey" PRIMARY KEY using index "user_challenge_assignments_pkey";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_pkey" PRIMARY KEY using index "user_metric_snapshots_pkey";

alter table "platform"."idempotency_records" add constraint "idempotency_records_pkey" PRIMARY KEY using index "idempotency_records_pkey";

alter table "platform"."outbox_events" add constraint "outbox_events_pkey" PRIMARY KEY using index "outbox_events_pkey";

alter table "prayer"."city_daily_aggregates" add constraint "city_daily_aggregates_pkey" PRIMARY KEY using index "city_daily_aggregates_pkey";

alter table "prayer"."country_daily_aggregates" add constraint "country_daily_aggregates_pkey" PRIMARY KEY using index "country_daily_aggregates_pkey";

alter table "prayer"."map_markers" add constraint "map_markers_pkey" PRIMARY KEY using index "map_markers_pkey";

alter table "prayer"."prayer_events" add constraint "prayer_events_pkey" PRIMARY KEY using index "prayer_events_pkey";

alter table "competition"."badge_definitions" add constraint "badge_definitions_category_check" CHECK ((category = ANY (ARRAY['prayer'::text, 'scripture'::text, 'service'::text, 'discipline'::text, 'community'::text, 'achievement'::text, 'seasonal'::text]))) not valid;

alter table "competition"."badge_definitions" validate constraint "badge_definitions_category_check";

alter table "competition"."badge_definitions" add constraint "badge_definitions_code_key" UNIQUE using index "badge_definitions_code_key";

alter table "competition"."badge_definitions" add constraint "badge_definitions_points_reward_check" CHECK ((points_reward >= 0)) not valid;

alter table "competition"."badge_definitions" validate constraint "badge_definitions_points_reward_check";

alter table "competition"."badge_definitions" add constraint "badge_definitions_rarity_check" CHECK ((rarity = ANY (ARRAY['common'::text, 'uncommon'::text, 'rare'::text, 'epic'::text, 'legendary'::text]))) not valid;

alter table "competition"."badge_definitions" validate constraint "badge_definitions_rarity_check";

alter table "competition"."badge_shares" add constraint "badge_shares_platform_check" CHECK ((platform = ANY (ARRAY['copy_link'::text, 'facebook'::text, 'instagram'::text, 'x'::text, 'whatsapp'::text, 'other'::text]))) not valid;

alter table "competition"."badge_shares" validate constraint "badge_shares_platform_check";

alter table "competition"."badge_shares" add constraint "badge_shares_share_token_key" UNIQUE using index "badge_shares_share_token_key";

alter table "competition"."badge_shares" add constraint "badge_shares_user_badge_id_fkey" FOREIGN KEY (user_badge_id) REFERENCES competition.user_badges(id) ON DELETE CASCADE not valid;

alter table "competition"."badge_shares" validate constraint "badge_shares_user_badge_id_fkey";

alter table "competition"."badge_shares" add constraint "badge_shares_visibility_check" CHECK ((visibility = ANY (ARRAY['public'::text, 'unlisted'::text, 'private'::text]))) not valid;

alter table "competition"."badge_shares" validate constraint "badge_shares_visibility_check";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_activity_id_fkey" FOREIGN KEY (activity_id) REFERENCES competition.spiritual_activities(id) not valid;

alter table "competition"."challenge_progress_events" validate constraint "challenge_progress_events_activity_id_fkey";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_assignment_id_fkey" FOREIGN KEY (assignment_id) REFERENCES competition.user_challenge_assignments(id) ON DELETE CASCADE not valid;

alter table "competition"."challenge_progress_events" validate constraint "challenge_progress_events_assignment_id_fkey";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_check" CHECK ((resulting_progress >= previous_progress)) not valid;

alter table "competition"."challenge_progress_events" validate constraint "challenge_progress_events_check";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_idempotency_key_key" UNIQUE using index "challenge_progress_events_idempotency_key_key";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_increment_amount_check" CHECK ((increment_amount > 0)) not valid;

alter table "competition"."challenge_progress_events" validate constraint "challenge_progress_events_increment_amount_check";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_previous_progress_check" CHECK ((previous_progress >= 0)) not valid;

alter table "competition"."challenge_progress_events" validate constraint "challenge_progress_events_previous_progress_check";

alter table "competition"."challenge_progress_events" add constraint "challenge_progress_events_resulting_progress_check" CHECK ((resulting_progress >= 0)) not valid;

alter table "competition"."challenge_progress_events" validate constraint "challenge_progress_events_resulting_progress_check";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_period_id_fkey" FOREIGN KEY (period_id) REFERENCES competition.leaderboard_periods(id) ON DELETE CASCADE not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_period_id_fkey";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_points_check" CHECK ((points >= 0)) not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_points_check";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_prayers_count_check" CHECK ((prayers_count >= 0)) not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_prayers_count_check";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_rank_check" CHECK (((rank IS NULL) OR (rank > 0))) not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_rank_check";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_rosaries_count_check" CHECK ((rosaries_count >= 0)) not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_rosaries_count_check";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_scope_type_check" CHECK ((scope_type = ANY (ARRAY['global'::text, 'country'::text, 'city'::text]))) not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_scope_type_check";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_scripture_readings_count_check" CHECK ((scripture_readings_count >= 0)) not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_scripture_readings_count_check";

alter table "competition"."leaderboard_entries" add constraint "leaderboard_entries_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."leaderboard_entries" validate constraint "leaderboard_entries_user_id_fkey";

alter table "competition"."leaderboard_periods" add constraint "leaderboard_periods_check" CHECK ((ends_at > starts_at)) not valid;

alter table "competition"."leaderboard_periods" validate constraint "leaderboard_periods_check";

alter table "competition"."leaderboard_periods" add constraint "leaderboard_periods_code_key" UNIQUE using index "leaderboard_periods_code_key";

alter table "competition"."leaderboard_periods" add constraint "leaderboard_periods_period_type_check" CHECK ((period_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'yearly'::text, 'season'::text]))) not valid;

alter table "competition"."leaderboard_periods" validate constraint "leaderboard_periods_period_type_check";

alter table "competition"."leaderboard_periods" add constraint "leaderboard_periods_status_check" CHECK ((status = ANY (ARRAY['scheduled'::text, 'active'::text, 'calculating'::text, 'finalized'::text]))) not valid;

alter table "competition"."leaderboard_periods" validate constraint "leaderboard_periods_status_check";

alter table "competition"."user_badge_progress" add constraint "user_badge_progress_badge_id_fkey" FOREIGN KEY (badge_id) REFERENCES competition.badge_definitions(id) ON DELETE CASCADE not valid;

alter table "competition"."user_badge_progress" validate constraint "user_badge_progress_badge_id_fkey";

alter table "competition"."user_badge_progress" add constraint "user_badge_progress_current_value_check" CHECK ((current_value >= 0)) not valid;

alter table "competition"."user_badge_progress" validate constraint "user_badge_progress_current_value_check";

alter table "competition"."user_badge_progress" add constraint "user_badge_progress_required_value_check" CHECK ((required_value > 0)) not valid;

alter table "competition"."user_badge_progress" validate constraint "user_badge_progress_required_value_check";

alter table "competition"."user_badge_progress" add constraint "user_badge_progress_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."user_badge_progress" validate constraint "user_badge_progress_user_id_fkey";

alter table "competition"."user_badges" add constraint "user_badges_badge_id_fkey" FOREIGN KEY (badge_id) REFERENCES competition.badge_definitions(id) not valid;

alter table "competition"."user_badges" validate constraint "user_badges_badge_id_fkey";

alter table "competition"."user_badges" add constraint "user_badges_sequence_number_check" CHECK ((sequence_number > 0)) not valid;

alter table "competition"."user_badges" validate constraint "user_badges_sequence_number_check";

alter table "competition"."user_badges" add constraint "user_badges_user_id_badge_id_sequence_number_key" UNIQUE using index "user_badges_user_id_badge_id_sequence_number_key";

alter table "competition"."user_badges" add constraint "user_badges_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."user_badges" validate constraint "user_badges_user_id_fkey";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_challenge_definition_id_fkey" FOREIGN KEY (challenge_definition_id) REFERENCES competition.challenge_definitions(id) not valid;

alter table "competition"."user_challenge_assignments" validate constraint "user_challenge_assignments_challenge_definition_id_fkey";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_check" CHECK ((expires_at > starts_at)) not valid;

alter table "competition"."user_challenge_assignments" validate constraint "user_challenge_assignments_check";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_check1" CHECK ((current_progress <= target_quantity)) not valid;

alter table "competition"."user_challenge_assignments" validate constraint "user_challenge_assignments_check1";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_current_progress_check" CHECK ((current_progress >= 0)) not valid;

alter table "competition"."user_challenge_assignments" validate constraint "user_challenge_assignments_current_progress_check";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'expired'::text, 'cancelled'::text]))) not valid;

alter table "competition"."user_challenge_assignments" validate constraint "user_challenge_assignments_status_check";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_target_quantity_check" CHECK ((target_quantity > 0)) not valid;

alter table "competition"."user_challenge_assignments" validate constraint "user_challenge_assignments_target_quantity_check";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_user_id_challenge_definition_id__key" UNIQUE using index "user_challenge_assignments_user_id_challenge_definition_id__key";

alter table "competition"."user_challenge_assignments" add constraint "user_challenge_assignments_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."user_challenge_assignments" validate constraint "user_challenge_assignments_user_id_fkey";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_points_earned_check" CHECK ((points_earned >= 0)) not valid;

alter table "competition"."user_metric_snapshots" validate constraint "user_metric_snapshots_points_earned_check";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_prayer_duration_seconds_check" CHECK ((prayer_duration_seconds >= 0)) not valid;

alter table "competition"."user_metric_snapshots" validate constraint "user_metric_snapshots_prayer_duration_seconds_check";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_prayer_sessions_count_check" CHECK ((prayer_sessions_count >= 0)) not valid;

alter table "competition"."user_metric_snapshots" validate constraint "user_metric_snapshots_prayer_sessions_count_check";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_rosaries_count_check" CHECK ((rosaries_count >= 0)) not valid;

alter table "competition"."user_metric_snapshots" validate constraint "user_metric_snapshots_rosaries_count_check";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_scripture_readings_count_check" CHECK ((scripture_readings_count >= 0)) not valid;

alter table "competition"."user_metric_snapshots" validate constraint "user_metric_snapshots_scripture_readings_count_check";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_service_acts_count_check" CHECK ((service_acts_count >= 0)) not valid;

alter table "competition"."user_metric_snapshots" validate constraint "user_metric_snapshots_service_acts_count_check";

alter table "competition"."user_metric_snapshots" add constraint "user_metric_snapshots_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "competition"."user_metric_snapshots" validate constraint "user_metric_snapshots_user_id_fkey";

alter table "platform"."idempotency_records" add constraint "idempotency_records_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "platform"."idempotency_records" validate constraint "idempotency_records_user_id_fkey";

alter table "platform"."idempotency_records" add constraint "idempotency_records_user_id_idempotency_key_key" UNIQUE using index "idempotency_records_user_id_idempotency_key_key";

alter table "platform"."outbox_events" add constraint "outbox_events_attempt_count_check" CHECK ((attempt_count >= 0)) not valid;

alter table "platform"."outbox_events" validate constraint "outbox_events_attempt_count_check";

alter table "platform"."outbox_events" add constraint "outbox_events_processing_status_check" CHECK ((processing_status = ANY (ARRAY['pending'::text, 'processing'::text, 'processed'::text, 'failed'::text]))) not valid;

alter table "platform"."outbox_events" validate constraint "outbox_events_processing_status_check";

alter table "prayer"."city_daily_aggregates" add constraint "city_daily_aggregates_city_id_fkey" FOREIGN KEY (city_id) REFERENCES app.cities(id) not valid;

alter table "prayer"."city_daily_aggregates" validate constraint "city_daily_aggregates_city_id_fkey";

alter table "prayer"."city_daily_aggregates" add constraint "city_daily_aggregates_prayer_duration_seconds_check" CHECK ((prayer_duration_seconds >= 0)) not valid;

alter table "prayer"."city_daily_aggregates" validate constraint "city_daily_aggregates_prayer_duration_seconds_check";

alter table "prayer"."city_daily_aggregates" add constraint "city_daily_aggregates_rosaries_check" CHECK ((rosaries >= 0)) not valid;

alter table "prayer"."city_daily_aggregates" validate constraint "city_daily_aggregates_rosaries_check";

alter table "prayer"."city_daily_aggregates" add constraint "city_daily_aggregates_total_prayers_check" CHECK ((total_prayers >= 0)) not valid;

alter table "prayer"."city_daily_aggregates" validate constraint "city_daily_aggregates_total_prayers_check";

alter table "prayer"."city_daily_aggregates" add constraint "city_daily_aggregates_unique_users_check" CHECK ((unique_users >= 0)) not valid;

alter table "prayer"."city_daily_aggregates" validate constraint "city_daily_aggregates_unique_users_check";

alter table "prayer"."country_daily_aggregates" add constraint "country_daily_aggregates_country_code_fkey" FOREIGN KEY (country_code) REFERENCES app.countries(code) not valid;

alter table "prayer"."country_daily_aggregates" validate constraint "country_daily_aggregates_country_code_fkey";

alter table "prayer"."country_daily_aggregates" add constraint "country_daily_aggregates_prayer_duration_seconds_check" CHECK ((prayer_duration_seconds >= 0)) not valid;

alter table "prayer"."country_daily_aggregates" validate constraint "country_daily_aggregates_prayer_duration_seconds_check";

alter table "prayer"."country_daily_aggregates" add constraint "country_daily_aggregates_rosaries_check" CHECK ((rosaries >= 0)) not valid;

alter table "prayer"."country_daily_aggregates" validate constraint "country_daily_aggregates_rosaries_check";

alter table "prayer"."country_daily_aggregates" add constraint "country_daily_aggregates_total_prayers_check" CHECK ((total_prayers >= 0)) not valid;

alter table "prayer"."country_daily_aggregates" validate constraint "country_daily_aggregates_total_prayers_check";

alter table "prayer"."country_daily_aggregates" add constraint "country_daily_aggregates_unique_users_check" CHECK ((unique_users >= 0)) not valid;

alter table "prayer"."country_daily_aggregates" validate constraint "country_daily_aggregates_unique_users_check";

alter table "prayer"."map_markers" add constraint "map_markers_aggregation_level_check" CHECK ((aggregation_level = ANY (ARRAY['country'::text, 'city'::text]))) not valid;

alter table "prayer"."map_markers" validate constraint "map_markers_aggregation_level_check";

alter table "prayer"."map_markers" add constraint "map_markers_aggregation_level_location_reference_period_sta_key" UNIQUE using index "map_markers_aggregation_level_location_reference_period_sta_key";

alter table "prayer"."map_markers" add constraint "map_markers_intensity_check" CHECK (((intensity >= (0)::numeric) AND (intensity <= (1)::numeric))) not valid;

alter table "prayer"."map_markers" validate constraint "map_markers_intensity_check";

alter table "prayer"."map_markers" add constraint "map_markers_prayer_count_check" CHECK ((prayer_count >= 0)) not valid;

alter table "prayer"."map_markers" validate constraint "map_markers_prayer_count_check";

alter table "prayer"."map_markers" add constraint "map_markers_unique_users_check" CHECK ((unique_users >= 0)) not valid;

alter table "prayer"."map_markers" validate constraint "map_markers_unique_users_check";

alter table "prayer"."prayer_events" add constraint "prayer_events_activity_id_fkey" FOREIGN KEY (activity_id) REFERENCES competition.spiritual_activities(id) not valid;

alter table "prayer"."prayer_events" validate constraint "prayer_events_activity_id_fkey";

alter table "prayer"."prayer_events" add constraint "prayer_events_city_id_fkey" FOREIGN KEY (city_id) REFERENCES app.cities(id) not valid;

alter table "prayer"."prayer_events" validate constraint "prayer_events_city_id_fkey";

alter table "prayer"."prayer_events" add constraint "prayer_events_country_code_fkey" FOREIGN KEY (country_code) REFERENCES app.countries(code) not valid;

alter table "prayer"."prayer_events" validate constraint "prayer_events_country_code_fkey";

alter table "prayer"."prayer_events" add constraint "prayer_events_prayer_type_check" CHECK ((prayer_type = ANY (ARRAY['rosary'::text, 'divine_mercy'::text, 'scripture'::text, 'intercession'::text, 'adoration'::text, 'other'::text]))) not valid;

alter table "prayer"."prayer_events" validate constraint "prayer_events_prayer_type_check";

alter table "prayer"."prayer_events" add constraint "prayer_events_quantity_check" CHECK ((quantity > 0)) not valid;

alter table "prayer"."prayer_events" validate constraint "prayer_events_quantity_check";

alter table "prayer"."prayer_events" add constraint "prayer_events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "prayer"."prayer_events" validate constraint "prayer_events_user_id_fkey";

alter table "prayer"."prayer_events" add constraint "prayer_events_visibility_check" CHECK ((visibility = ANY (ARRAY['aggregated'::text, 'private'::text]))) not valid;

alter table "prayer"."prayer_events" validate constraint "prayer_events_visibility_check";

CREATE TRIGGER trg_badge_definitions_updated_at BEFORE UPDATE ON competition.badge_definitions FOR EACH ROW EXECUTE FUNCTION platform.set_updated_at();

CREATE TRIGGER trg_user_challenge_assignments_updated_at BEFORE UPDATE ON competition.user_challenge_assignments FOR EACH ROW EXECUTE FUNCTION platform.set_updated_at();


