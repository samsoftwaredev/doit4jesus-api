-- Make the application's custom schemas available through the Supabase Data API.
-- Row-level security remains responsible for deciding which rows each API role
-- can access.

grant usage on schema app, competition, prayer, platform
to anon, authenticated, service_role;

grant all on all tables in schema app, competition, prayer, platform
to anon, authenticated, service_role;

grant all on all routines in schema app, competition, prayer, platform
to anon, authenticated, service_role;

grant all on all sequences in schema app, competition, prayer, platform
to anon, authenticated, service_role;

alter default privileges for role postgres in schema app
grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema app
grant all on routines to anon, authenticated, service_role;
alter default privileges for role postgres in schema app
grant all on sequences to anon, authenticated, service_role;

alter default privileges for role postgres in schema competition
grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema competition
grant all on routines to anon, authenticated, service_role;
alter default privileges for role postgres in schema competition
grant all on sequences to anon, authenticated, service_role;

alter default privileges for role postgres in schema prayer
grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema prayer
grant all on routines to anon, authenticated, service_role;
alter default privileges for role postgres in schema prayer
grant all on sequences to anon, authenticated, service_role;

alter default privileges for role postgres in schema platform
grant all on tables to anon, authenticated, service_role;
alter default privileges for role postgres in schema platform
grant all on routines to anon, authenticated, service_role;
alter default privileges for role postgres in schema platform
grant all on sequences to anon, authenticated, service_role;
