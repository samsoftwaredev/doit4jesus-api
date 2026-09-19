-- Keep the seed honest as the schema evolves. This runs after every configured
-- seed file, including the examination-of-conscience data set.
do $$
declare
  table_record record;
  has_rows boolean;
begin
  for table_record in
    select table_schema, table_name
    from information_schema.tables
    where table_type = 'BASE TABLE'
      and table_schema in ('app', 'competition', 'prayer', 'platform')
    order by table_schema, table_name
  loop
    execute format(
      'select exists (select 1 from %I.%I)',
      table_record.table_schema,
      table_record.table_name
    ) into has_rows;

    if not has_rows then
      raise exception 'Seed data is missing for %.%', table_record.table_schema, table_record.table_name;
    end if;
  end loop;
end
$$;

do $$
begin
  if exists (
    select 1
    from competition.leaderboard_periods
    where period_type not in ('weekly', 'yearly')
  ) then
    raise exception 'Unsupported leaderboard periods are present';
  end if;

  if not exists (
    select 1
    from competition.leaderboard_periods
    where period_type = 'weekly'
      and status = 'active'
      and starts_at <= now()
      and ends_at > now()
  ) then
    raise exception 'The current weekly leaderboard period is missing';
  end if;

  if not exists (
    select 1
    from competition.leaderboard_periods
    where period_type = 'yearly'
      and status = 'active'
      and starts_at <= now()
      and ends_at > now()
  ) then
    raise exception 'The current yearly leaderboard period is missing';
  end if;
end
$$;
