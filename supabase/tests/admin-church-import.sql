-- Run against the local seeded database. Every data change is rolled back.
begin;

do $$
declare
  v_admin_id uuid := '33333333-3333-4333-8333-333333333333';
  v_non_admin_id uuid;
  v_result jsonb;
  v_church_id uuid;
  v_times integer;
  v_failed boolean;
  v_church jsonb := '{"name":"Import Test Parish","address_line_1":"9 Import Way","city":"Austin","region_name":"TX","postal_code":"78701","country_code":"US","timezone":"America/Chicago","latitude":30.27,"longitude":-97.74}';
  v_first jsonb := '[{"service_type":"mass","weekday":0,"starts_at":"09:00","ends_at":null},{"service_type":"confession","weekday":6,"starts_at":"16:00","ends_at":"16:45"}]';
  v_second jsonb := '[{"service_type":"mass","weekday":0,"starts_at":"10:30","ends_at":null}]';
begin
  select account.id into v_non_admin_id
  from app.users account
  where not exists (
    select 1 from app.user_roles role_record
    where role_record.user_id = account.id and role_record.role = 'admin'
  )
  limit 1;

  if v_non_admin_id is not null then
    perform set_config('request.jwt.claim.sub', v_non_admin_id::text, true);
    v_failed := false;
    begin
      perform api.admin_import_church_schedule(null, v_church, v_first, true);
    exception when others then
      v_failed := sqlerrm = 'FORBIDDEN';
    end;
    if not v_failed then raise exception 'Expected a non-administrator to be rejected'; end if;
  end if;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  -- Missing Mass is rejected.
  v_failed := false;
  begin
    perform api.admin_import_church_schedule(null, v_church,
      '[{"service_type":"adoration","weekday":5,"starts_at":"18:00","ends_at":null}]'::jsonb, true);
  exception when others then
    v_failed := sqlerrm = 'INCOMPLETE_CHURCH_SERVICE_TIMES';
  end;
  if not v_failed then raise exception 'Expected an import without Mass to be rejected'; end if;

  -- Dry run on an unknown church reports create and saves nothing.
  v_result := api.admin_import_church_schedule(null, v_church, v_first, true);
  if v_result ->> 'action' <> 'create' then raise exception 'Expected create, got %', v_result; end if;
  if exists (select 1 from app.churches where name = 'Import Test Parish') then
    raise exception 'Dry run must not create the church';
  end if;

  -- Apply creates it, verified, with its schedule.
  v_result := api.admin_import_church_schedule(null, v_church, v_first, false);
  v_church_id := (v_result ->> 'churchId')::uuid;
  select count(*) into v_times from app.church_service_times where church_id = v_church_id;
  if v_result ->> 'action' <> 'create' or v_times <> 2 then
    raise exception 'Expected created church with 2 times, got % / %', v_result, v_times;
  end if;

  -- Same name + address matches and updates (replaces times).
  v_result := api.admin_import_church_schedule(null, v_church, v_second, false);
  if v_result ->> 'action' <> 'update' or (v_result ->> 'churchId')::uuid <> v_church_id then
    raise exception 'Expected update of the created church, got %', v_result;
  end if;
  select count(*) into v_times from app.church_service_times where church_id = v_church_id;
  if v_times <> 1 then raise exception 'Expected 1 time after replacement, found %', v_times; end if;

  -- churchId match, dry run reports the current times and changes nothing.
  v_result := api.admin_import_church_schedule(v_church_id, '{}'::jsonb, v_first, true);
  if v_result ->> 'action' <> 'update' or jsonb_array_length(v_result -> 'currentServiceTimes') <> 1 then
    raise exception 'Expected dry-run update preview, got %', v_result;
  end if;
  select count(*) into v_times from app.church_service_times where church_id = v_church_id;
  if v_times <> 1 then raise exception 'Dry run must not change times'; end if;

  -- Unknown churchId is reported, not raised.
  v_result := api.admin_import_church_schedule('00000000-0000-4000-8000-0000000000ff', '{}'::jsonb, v_first, true);
  if v_result ->> 'action' <> 'invalid' then raise exception 'Expected invalid for unknown churchId'; end if;
end
$$;

rollback;
