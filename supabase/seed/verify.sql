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
