-- Match database access to the authenticated Next.js API routes.
--
-- The API always uses an end-user JWT. Client roles receive only the table
-- privileges used by those routes, while RLS decides which rows are visible.
-- Internal projection, scoring, idempotency, and outbox tables remain available
-- only to postgres/service_role workers.

create schema if not exists api;

-- The notification routes and generated types already depend on this table,
-- but the original table definition only existed as a SQL snippet.
create table if not exists app.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app.users(id) on delete cascade,
  notification_type varchar(100) not null,
  title varchar(200) not null,
  body text,
  action_url text,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_unread
  on app.notifications (user_id, created_at desc)
  where read_at is null;

-- Leaderboards need a small public-profile projection. Keeping this projection
-- separate prevents public profiles from exposing language, timezone, location,
-- and privacy settings through direct Data API queries.
create or replace view app.leaderboard_profiles
with (security_barrier = true)
as
select
  user_id,
  display_name,
  username,
  avatar_url,
  title
from app.user_profiles
where leaderboard_visibility = 'public'
   or user_id = (select auth.uid());

-- Keep RLS enabled explicitly so this migration remains safe if applied to a
-- database whose baseline schema was created outside these migrations.
alter table app.cities enable row level security;
alter table app.countries enable row level security;
alter table app.notifications enable row level security;
alter table app.user_profiles enable row level security;
alter table app.users enable row level security;

alter table competition.activity_definitions enable row level security;
alter table competition.badge_definitions enable row level security;
alter table competition.badge_shares enable row level security;
alter table competition.challenge_definitions enable row level security;
alter table competition.challenge_progress_events enable row level security;
alter table competition.leaderboard_entries enable row level security;
alter table competition.leaderboard_periods enable row level security;
alter table competition.level_definitions enable row level security;
alter table competition.point_ledger enable row level security;
alter table competition.point_rules enable row level security;
alter table competition.spiritual_activities enable row level security;
alter table competition.user_badge_progress enable row level security;
alter table competition.user_badges enable row level security;
alter table competition.user_challenge_assignments enable row level security;
alter table competition.user_metric_snapshots enable row level security;
alter table competition.user_progress enable row level security;

alter table prayer.city_daily_aggregates enable row level security;
alter table prayer.country_daily_aggregates enable row level security;
alter table prayer.map_markers enable row level security;
alter table prayer.prayer_events enable row level security;

alter table platform.idempotency_records enable row level security;
alter table platform.outbox_events enable row level security;

-- Remove the broad grants from the imported baseline. RLS is the primary row
-- boundary, while these grants prevent direct writes to server-managed fields.
revoke all privileges on all tables in schema app from anon, authenticated;
revoke all privileges on all tables in schema competition from anon, authenticated;
revoke all privileges on all tables in schema prayer from anon, authenticated;
revoke all privileges on all tables in schema platform from anon, authenticated;

revoke all privileges on all sequences in schema app from anon, authenticated;
revoke all privileges on all sequences in schema competition from anon, authenticated;
revoke all privileges on all sequences in schema prayer from anon, authenticated;
revoke all privileges on all sequences in schema platform from anon, authenticated;

revoke usage on schema app, competition, prayer, platform from anon;
revoke usage on schema platform from authenticated;
revoke execute on all functions in schema platform from public, anon, authenticated;

grant usage on schema app, competition, prayer, api to authenticated;
grant usage on schema app, competition, prayer, platform, api to service_role;

grant select on
  app.cities,
  app.countries,
  app.leaderboard_profiles,
  app.notifications,
  app.user_profiles
to authenticated;

grant update (
  display_name,
  username,
  avatar_url,
  title,
  preferred_language,
  timezone,
  city_id,
  country_code,
  leaderboard_visibility,
  prayer_map_visibility
) on app.user_profiles to authenticated;

grant update (read_at) on app.notifications to authenticated;

grant select on
  competition.activity_definitions,
  competition.badge_definitions,
  competition.badge_shares,
  competition.challenge_definitions,
  competition.challenge_progress_events,
  competition.leaderboard_entries,
  competition.leaderboard_periods,
  competition.level_definitions,
  competition.point_ledger,
  competition.spiritual_activities,
  competition.user_badge_progress,
  competition.user_badges,
  competition.user_challenge_assignments,
  competition.user_metric_snapshots,
  competition.user_progress
to authenticated;

grant select on prayer.map_markers, prayer.prayer_events to authenticated;

grant all privileges on app.notifications to service_role;
grant select on app.leaderboard_profiles to service_role;

-- Do not automatically expose future tables or functions to client roles.
alter default privileges for role postgres in schema app
revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema competition
revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema prayer
revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema platform
revoke all on tables from anon, authenticated;

alter default privileges for role postgres in schema app
revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema competition
revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema prayer
revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema platform
revoke all on sequences from anon, authenticated;

alter default privileges for role postgres in schema app
revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema competition
revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema prayer
revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema platform
revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema api
revoke execute on functions from public, anon, authenticated;

-- Reference and catalog data used by authenticated API routes.
create policy countries_select_active_authenticated
on app.countries
for select
to authenticated
using (is_active);

create policy cities_select_active_authenticated
on app.cities
for select
to authenticated
using (is_active);

create policy activity_definitions_select_active_authenticated
on competition.activity_definitions
for select
to authenticated
using (is_active);

create policy badge_definitions_select_active_authenticated
on competition.badge_definitions
for select
to authenticated
using (is_active);

create policy challenge_definitions_select_authenticated
on competition.challenge_definitions
for select
to authenticated
using (true);

create policy level_definitions_select_active_authenticated
on competition.level_definitions
for select
to authenticated
using (is_active);

create policy leaderboard_periods_select_authenticated
on competition.leaderboard_periods
for select
to authenticated
using (true);

create policy leaderboard_entries_select_authenticated
on competition.leaderboard_entries
for select
to authenticated
using (true);

-- The prayer map route enforces the same privacy threshold in application code;
-- retaining it here prevents a direct Data API query from returning small cells.
create policy map_markers_select_privacy_safe_authenticated
on prayer.map_markers
for select
to authenticated
using (unique_users >= 5);

-- User-owned application rows.
create policy user_profiles_select_own
on app.user_profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy user_profiles_update_own
on app.user_profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy notifications_select_own
on app.notifications
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy notifications_update_own
on app.notifications
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy spiritual_activities_select_own
on competition.spiritual_activities
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy point_ledger_select_own
on competition.point_ledger
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy user_progress_select_own
on competition.user_progress
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy user_challenge_assignments_select_own
on competition.user_challenge_assignments
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy challenge_progress_events_select_own
on competition.challenge_progress_events
for select
to authenticated
using (
  exists (
    select 1
    from competition.user_challenge_assignments assignment
    where assignment.id = challenge_progress_events.assignment_id
      and assignment.user_id = (select auth.uid())
  )
);

create policy user_badges_select_own
on competition.user_badges
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy user_badge_progress_select_own
on competition.user_badge_progress
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy badge_shares_select_own
on competition.badge_shares
for select
to authenticated
using (
  exists (
    select 1
    from competition.user_badges earned_badge
    where earned_badge.id = badge_shares.user_badge_id
      and earned_badge.user_id = (select auth.uid())
  )
);

create policy user_metric_snapshots_select_own
on competition.user_metric_snapshots
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy prayer_events_select_own
on prayer.prayer_events
for select
to authenticated
using ((select auth.uid()) = user_id);

-- Deliberately no client policies are created for app.users, point_rules, raw
-- prayer aggregates, idempotency_records, or outbox_events. With RLS enabled
-- and no client grants, those server-managed tables are default-deny.
