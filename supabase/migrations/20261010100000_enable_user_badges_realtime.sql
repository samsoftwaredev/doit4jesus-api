-- Signed-in users receive badge-award notifications through authorized
-- Postgres Changes. The existing RLS policy exposes only each user's rows.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'competition'
      and tablename = 'user_badges'
  ) then
    alter publication supabase_realtime add table competition.user_badges;
  end if;
end;
$$;
