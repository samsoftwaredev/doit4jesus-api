-- Run against the local seeded database. Every data change is rolled back.
begin;

do $$
declare
  v_admin_id uuid := '33333333-3333-4333-8333-333333333333';
  v_non_admin_id uuid;
  v_church_id uuid;
  v_task_id uuid;
  v_result jsonb;
  v_times integer;
  v_failed boolean;
begin
  if not exists (
    select 1 from app.user_roles where user_id = v_admin_id and role = 'admin'
  ) then
    raise exception 'Expected seeded administrator %', v_admin_id;
  end if;
  select account.id into v_non_admin_id
  from app.users account
  where not exists (
    select 1 from app.user_roles role_record
    where role_record.user_id = account.id and role_record.role = 'admin'
  )
  limit 1;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  -- A church without a Mass time is rejected.
  v_failed := false;
  begin
    perform api.admin_create_church(
      '{"name":"SQL Test Parish","address_line_1":"1 Test Way","city":"Austin","region_name":"TX","postal_code":"78701","country_code":"US","timezone":"America/Chicago","latitude":30.27,"longitude":-97.74}'::jsonb,
      '[{"service_type":"adoration","weekday":5,"starts_at":"18:00","ends_at":null}]'::jsonb
    );
  exception when others then
    v_failed := sqlerrm = 'INCOMPLETE_CHURCH_SERVICE_TIMES';
  end;
  if not v_failed then raise exception 'Expected a church without Mass to be rejected'; end if;

  -- Mass-only creation succeeds, collapses duplicates, and is verified.
  v_result := api.admin_create_church(
    '{"name":"SQL Test Parish","address_line_1":"1 Test Way","city":"Austin","region_name":"TX","postal_code":"78701","country_code":"US","timezone":"America/Chicago","latitude":30.27,"longitude":-97.74}'::jsonb,
    '[
      {"service_type":"mass","weekday":0,"starts_at":"09:00","ends_at":null},
      {"service_type":"mass","weekday":0,"starts_at":"09:00","ends_at":null},
      {"service_type":"mass","weekday":0,"starts_at":"11:00","ends_at":null}
    ]'::jsonb
  );
  v_church_id := (v_result ->> 'churchId')::uuid;
  select count(*) into v_times from app.church_service_times where church_id = v_church_id;
  if v_times <> 2 then raise exception 'Expected 2 collapsed service times, found %', v_times; end if;
  if not exists (
    select 1 from app.churches
    where id = v_church_id and is_active
      and directory_verification_status = 'verified'
      and schedule_verified_at is not null and source is null
  ) then
    raise exception 'Expected the created church to be active and verified';
  end if;

  -- The same name, address, and postal code is a duplicate.
  v_failed := false;
  begin
    perform api.admin_create_church(
      '{"name":"sql test parish","address_line_1":"1 TEST WAY","city":"Austin","postal_code":"78701","country_code":"US","timezone":"America/Chicago","latitude":30.27,"longitude":-97.74}'::jsonb,
      '[{"service_type":"mass","weekday":0,"starts_at":"08:00","ends_at":null}]'::jsonb
    );
  exception when others then
    v_failed := sqlerrm = 'CHURCH_ALREADY_EXISTS';
  end;
  if not v_failed then raise exception 'Expected the duplicate church to be rejected'; end if;

  -- Verifying a pending review needs only Mass; confession and adoration stay optional.
  insert into app.church_schedule_review_tasks (church_id, request_reason)
  values (v_church_id, 'missing_schedule')
  returning id into v_task_id;
  v_failed := false;
  begin
    perform api.review_church_schedule_task(
      v_task_id, 'verified', '{}'::jsonb,
      '[{"service_type":"confession","weekday":6,"starts_at":"16:00","ends_at":"16:45"}]'::jsonb, null
    );
  exception when others then
    v_failed := sqlerrm = 'INCOMPLETE_CHURCH_SERVICE_TIMES';
  end;
  if not v_failed then raise exception 'Expected verification without Mass to be rejected'; end if;

  perform api.review_church_schedule_task(
    v_task_id, 'verified', '{}'::jsonb,
    '[
      {"service_type":"mass","weekday":0,"starts_at":"07:00","ends_at":null},
      {"service_type":"mass","weekday":0,"starts_at":"07:00","ends_at":null},
      {"service_type":"mass","weekday":0,"starts_at":"09:00","ends_at":null}
    ]'::jsonb, null
  );
  select count(*) into v_times from app.church_service_times
  where church_id = v_church_id and service_type = 'mass';
  if v_times <> 2 then raise exception 'Expected 2 Mass times after review, found %', v_times; end if;
  if exists (
    select 1 from app.church_service_times
    where church_id = v_church_id and service_type <> 'mass'
  ) then
    raise exception 'Expected no optional services after a Mass-only review';
  end if;
  if not exists (
    select 1 from app.church_schedule_review_tasks
    where id = v_task_id and status = 'completed' and outcome = 'verified'
  ) then
    raise exception 'Expected the review to be completed as verified';
  end if;

  -- Non-administrators cannot create churches.
  if v_non_admin_id is not null then
    perform set_config('request.jwt.claim.sub', v_non_admin_id::text, true);
    v_failed := false;
    begin
      perform api.admin_create_church(
        '{"name":"Nope","address_line_1":"2 Test Way","city":"Austin","country_code":"US","timezone":"America/Chicago","latitude":30.27,"longitude":-97.74}'::jsonb,
        '[{"service_type":"mass","weekday":0,"starts_at":"09:00","ends_at":null}]'::jsonb
      );
    exception when others then
      v_failed := sqlerrm = 'FORBIDDEN';
    end;
    if not v_failed then raise exception 'Expected a non-administrator to be rejected'; end if;
  end if;
end
$$;

rollback;
