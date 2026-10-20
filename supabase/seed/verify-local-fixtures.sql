-- Verify the explicitly requested local operational fixture. This file is not
-- part of the default Supabase seed path.
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
      -- These tables capture real operational activity and are deliberately
      -- not populated solely to make fixture verification pass.
      and (table_schema, table_name) not in (
        ('app', 'email_campaigns'),
        ('app', 'email_sends'),
        ('app', 'email_suppressions'),
        ('app', 'email_test_recipients'),
        ('app', 'email_test_runs'),
        ('app', 'email_webhook_events'),
        ('app', 'events'),
        ('app', 'event_attendees'),
        ('app', 'event_views')
      )
    order by table_schema, table_name
  loop
    execute format(
      'select exists (select 1 from %I.%I)',
      table_record.table_schema,
      table_record.table_name
    ) into has_rows;

    if not has_rows then
      raise exception 'Local fixture data is missing for %.%', table_record.table_schema, table_record.table_name;
    end if;
  end loop;
end
$$;

do $$
declare
  fixture_account_count integer;
begin
  select count(*)
  into fixture_account_count
  from auth.users auth_user
  where (auth_user.id, lower(auth_user.email)) in (
    ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'::uuid, 'test@test.com'),
    ('33333333-3333-4333-8333-333333333333'::uuid, 'test@admin.com'),
    ('11111111-1111-4111-8111-111111111111'::uuid, 'maria@example.com'),
    ('22222222-2222-4222-8222-222222222222'::uuid, 'john@example.com')
  );

  if fixture_account_count <> 4 then
    raise exception 'Expected all four local fixture Auth accounts; found %', fixture_account_count;
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from competition.leaderboard_periods
    where period_type not in ('weekly', 'yearly', 'lifetime')
  ) then
    raise exception 'Unsupported local-fixture leaderboard periods are present';
  end if;

  if not exists (
    select 1
    from competition.leaderboard_periods
    where period_type = 'weekly'
      and status = 'active'
      and starts_at <= now()
      and ends_at > now()
  ) then
    raise exception 'The local fixture current weekly leaderboard period is missing';
  end if;

  if not exists (
    select 1
    from competition.leaderboard_periods
    where period_type = 'yearly'
      and status = 'active'
      and starts_at <= now()
      and ends_at > now()
  ) then
    raise exception 'The local fixture current yearly leaderboard period is missing';
  end if;

  if not exists (
    select 1
    from competition.leaderboard_periods
    where period_type = 'lifetime'
      and code = 'lifetime'
      and status = 'active'
  ) then
    raise exception 'The local fixture lifetime leaderboard period is missing';
  end if;

  if exists (
    with lifetime_period as (
      select id, ends_at
      from competition.leaderboard_periods
      where period_type = 'lifetime'
        and code = 'lifetime'
    ), totals as (
      select
        activity.user_id,
        sum(activity.quantity)::integer as rosaries_count
      from competition.spiritual_activities activity
      cross join lifetime_period period
      where activity.occurred_at <= period.ends_at
        and activity.activity_code = 'ROSARY'
        and activity.verification_status in ('self_reported', 'verified')
      group by activity.user_id
      having sum(activity.quantity) > 0
    ), expected as (
      select
        totals.user_id,
        totals.rosaries_count,
        rank() over (order by totals.rosaries_count desc)::integer as rank
      from totals
    ), actual as (
      select entry.user_id, entry.rosaries_count, entry.rank
      from competition.leaderboard_entries entry
      join lifetime_period period on period.id = entry.period_id
      where entry.scope_type = 'global'
        and entry.scope_reference = 'global'
    )
    select 1
    from expected
    full join actual using (user_id)
    where expected.user_id is null
      or actual.user_id is null
      or expected.rosaries_count <> actual.rosaries_count
      or expected.rank <> actual.rank
  ) then
    raise exception 'The local fixture lifetime Rosary projection is incorrect';
  end if;
end
$$;
