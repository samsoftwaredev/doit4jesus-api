create schema if not exists "competition";

create schema if not exists "platform";

create schema if not exists "prayer";

create extension if not exists "citext" with schema "public";


  create table "app"."cities" (
    "id" uuid not null default gen_random_uuid(),
    "country_code" character(2) not null,
    "name" character varying(150) not null,
    "region_name" character varying(150),
    "latitude" numeric(9,6) not null,
    "longitude" numeric(9,6) not null,
    "timezone" character varying(100),
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now()
      );


alter table "app"."cities" enable row level security;


  create table "app"."countries" (
    "code" character(2) not null,
    "name" character varying(120) not null,
    "latitude" numeric(9,6),
    "longitude" numeric(9,6),
    "is_active" boolean not null default true
      );


alter table "app"."countries" enable row level security;


  create table "app"."user_profiles" (
    "user_id" uuid not null,
    "display_name" character varying(80) not null,
    "username" public.citext,
    "avatar_url" text,
    "title" character varying(100),
    "preferred_language" character varying(10) not null default 'en'::character varying,
    "timezone" character varying(100) not null default 'UTC'::character varying,
    "city_id" uuid,
    "country_code" character(2),
    "leaderboard_visibility" text not null default 'public'::text,
    "prayer_map_visibility" text not null default 'aggregated'::text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "app"."user_profiles" enable row level security;


  create table "app"."users" (
    "id" uuid not null default gen_random_uuid(),
    "email" public.citext not null,
    "password_hash" text,
    "status" text not null default 'active'::text,
    "email_verified_at" timestamp with time zone,
    "last_login_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "deleted_at" timestamp with time zone
      );


alter table "app"."users" enable row level security;


  create table "competition"."activity_definitions" (
    "code" character varying(50) not null,
    "name" character varying(100) not null,
    "description" text,
    "category" text not null,
    "requires_duration" boolean not null default false,
    "requires_verification" boolean not null default false,
    "is_repeatable" boolean not null default true,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "competition"."activity_definitions" enable row level security;

CREATE UNIQUE INDEX cities_country_code_name_region_name_key ON app.cities USING btree (country_code, name, region_name);

CREATE UNIQUE INDEX cities_pkey ON app.cities USING btree (id);

CREATE UNIQUE INDEX countries_pkey ON app.countries USING btree (code);

CREATE INDEX idx_cities_country ON app.cities USING btree (country_code);

CREATE INDEX idx_user_profiles_country ON app.user_profiles USING btree (country_code);

CREATE INDEX idx_user_profiles_username ON app.user_profiles USING btree (username);

CREATE INDEX idx_users_status ON app.users USING btree (status) WHERE (deleted_at IS NULL);

CREATE UNIQUE INDEX user_profiles_pkey ON app.user_profiles USING btree (user_id);

CREATE UNIQUE INDEX user_profiles_username_key ON app.user_profiles USING btree (username);

CREATE UNIQUE INDEX users_email_key ON app.users USING btree (email);

CREATE UNIQUE INDEX users_pkey ON app.users USING btree (id);

CREATE UNIQUE INDEX activity_definitions_pkey ON competition.activity_definitions USING btree (code);

alter table "app"."cities" add constraint "cities_pkey" PRIMARY KEY using index "cities_pkey";

alter table "app"."countries" add constraint "countries_pkey" PRIMARY KEY using index "countries_pkey";

alter table "app"."user_profiles" add constraint "user_profiles_pkey" PRIMARY KEY using index "user_profiles_pkey";

alter table "app"."users" add constraint "users_pkey" PRIMARY KEY using index "users_pkey";

alter table "competition"."activity_definitions" add constraint "activity_definitions_pkey" PRIMARY KEY using index "activity_definitions_pkey";

alter table "app"."cities" add constraint "cities_country_code_fkey" FOREIGN KEY (country_code) REFERENCES app.countries(code) not valid;

alter table "app"."cities" validate constraint "cities_country_code_fkey";

alter table "app"."cities" add constraint "cities_country_code_name_region_name_key" UNIQUE using index "cities_country_code_name_region_name_key";

alter table "app"."user_profiles" add constraint "fk_user_profiles_city" FOREIGN KEY (city_id) REFERENCES app.cities(id) not valid;

alter table "app"."user_profiles" validate constraint "fk_user_profiles_city";

alter table "app"."user_profiles" add constraint "user_profiles_leaderboard_visibility_check" CHECK ((leaderboard_visibility = ANY (ARRAY['public'::text, 'friends'::text, 'private'::text]))) not valid;

alter table "app"."user_profiles" validate constraint "user_profiles_leaderboard_visibility_check";

alter table "app"."user_profiles" add constraint "user_profiles_prayer_map_visibility_check" CHECK ((prayer_map_visibility = ANY (ARRAY['aggregated'::text, 'hidden'::text]))) not valid;

alter table "app"."user_profiles" validate constraint "user_profiles_prayer_map_visibility_check";

alter table "app"."user_profiles" add constraint "user_profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES app.users(id) ON DELETE CASCADE not valid;

alter table "app"."user_profiles" validate constraint "user_profiles_user_id_fkey";

alter table "app"."user_profiles" add constraint "user_profiles_username_key" UNIQUE using index "user_profiles_username_key";

alter table "app"."users" add constraint "users_email_key" UNIQUE using index "users_email_key";

alter table "app"."users" add constraint "users_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'deleted'::text]))) not valid;

alter table "app"."users" validate constraint "users_status_check";

alter table "competition"."activity_definitions" add constraint "activity_definitions_category_check" CHECK ((category = ANY (ARRAY['prayer'::text, 'scripture'::text, 'service'::text, 'sacrifice'::text, 'discipline'::text, 'community'::text, 'other'::text]))) not valid;

alter table "competition"."activity_definitions" validate constraint "activity_definitions_category_check";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION platform.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

BEGIN

  NEW.updated_at = NOW();

  RETURN NEW;

END;

$function$
;

CREATE TRIGGER trg_user_profiles_updated_at BEFORE UPDATE ON app.user_profiles FOR EACH ROW EXECUTE FUNCTION platform.set_updated_at();

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON app.users FOR EACH ROW EXECUTE FUNCTION platform.set_updated_at();

CREATE TRIGGER trg_activity_definitions_updated_at BEFORE UPDATE ON competition.activity_definitions FOR EACH ROW EXECUTE FUNCTION platform.set_updated_at();


