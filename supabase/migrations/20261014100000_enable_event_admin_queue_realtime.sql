-- Pending event moderation joins the existing administrator queue bell.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'app'
      and tablename = 'events'
  ) then
    alter publication supabase_realtime add table app.events;
  end if;
end;
$$;
