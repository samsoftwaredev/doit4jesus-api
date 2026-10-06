-- The administrator queue bell refreshes from authorized Postgres Changes.
-- Existing table grants and RLS policies keep previews visible only to admins.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'app'
      and tablename = 'contact_requests'
  ) then
    alter publication supabase_realtime add table app.contact_requests;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'prayer'
      and tablename = 'prayer_intentions'
  ) then
    alter publication supabase_realtime add table prayer.prayer_intentions;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'app'
      and tablename = 'church_change_requests'
  ) then
    alter publication supabase_realtime add table app.church_change_requests;
  end if;
end;
$$;
