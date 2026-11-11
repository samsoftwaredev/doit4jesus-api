-- Mass is the only mandatory service when an administrator verifies a church
-- schedule; confession and Eucharistic adoration are optional. Administrators
-- can also add a church that is missing from the imported directory.

create or replace function api.review_church_schedule_task(
  p_review_id uuid,
  p_decision text,
  p_church jsonb default '{}'::jsonb,
  p_service_times jsonb default '[]'::jsonb,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_task app.church_schedule_review_tasks%rowtype;
begin
  if v_admin_id is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;
  if not app.is_current_user_admin() then raise exception 'FORBIDDEN' using errcode = 'P0001'; end if;
  if p_decision not in ('verified', 'closed') then
    raise exception 'INVALID_CHURCH_SCHEDULE_DECISION' using errcode = 'P0001';
  end if;

  select * into v_task from app.church_schedule_review_tasks task
  where task.id = p_review_id for update;
  if not found then raise exception 'CHURCH_SCHEDULE_REVIEW_NOT_FOUND' using errcode = 'P0001'; end if;
  if v_task.status <> 'pending' then raise exception 'CHURCH_SCHEDULE_REVIEW_NOT_PENDING' using errcode = 'P0001'; end if;

  perform 1 from app.churches church where church.id = v_task.church_id for update;
  if not found then raise exception 'CHURCH_NOT_FOUND' using errcode = 'P0001'; end if;

  if p_decision = 'verified' then
    if jsonb_typeof(p_service_times) <> 'array'
      or jsonb_array_length(p_service_times) = 0
      or not ('mass' = any(array(select item ->> 'service_type' from jsonb_array_elements(p_service_times) item))) then
      raise exception 'INCOMPLETE_CHURCH_SERVICE_TIMES' using errcode = 'P0001';
    end if;

    update app.churches
    set
      name = coalesce(nullif(btrim(p_church ->> 'name'), ''), name),
      address_line_1 = coalesce(nullif(btrim(p_church ->> 'address_line_1'), ''), address_line_1),
      address_line_2 = case when p_church ? 'address_line_2' then nullif(btrim(p_church ->> 'address_line_2'), '') else address_line_2 end,
      city = coalesce(nullif(btrim(p_church ->> 'city'), ''), city),
      region_name = case when p_church ? 'region_name' then nullif(btrim(p_church ->> 'region_name'), '') else region_name end,
      postal_code = case when p_church ? 'postal_code' then nullif(btrim(p_church ->> 'postal_code'), '') else postal_code end,
      country_code = coalesce(nullif(upper(btrim(p_church ->> 'country_code')), '')::char(2), country_code),
      timezone = coalesce(nullif(btrim(p_church ->> 'timezone'), ''), timezone),
      latitude = case when p_church ? 'latitude' then (p_church ->> 'latitude')::numeric else latitude end,
      longitude = case when p_church ? 'longitude' then (p_church ->> 'longitude')::numeric else longitude end,
      diocese_id = case when p_church ? 'diocese_id' then nullif(p_church ->> 'diocese_id', '')::uuid else diocese_id end,
      is_active = true,
      directory_verification_status = 'verified',
      directory_verified_at = now(),
      directory_verified_by = v_admin_id
    where id = v_task.church_id;

    delete from app.church_service_times where church_id = v_task.church_id;
    -- distinct: the unique key ignores ends_at, so repeated times must collapse.
    insert into app.church_service_times (church_id, service_type, weekday, starts_at, ends_at)
    select distinct on (proposed.service_type, proposed.weekday, proposed.starts_at)
      v_task.church_id, proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at
    from jsonb_to_recordset(p_service_times) as proposed(
      service_type text, weekday smallint, starts_at time, ends_at time
    )
    order by proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at nulls last;

    update app.churches
    set schedule_verified_at = now(), schedule_verified_by = v_admin_id
    where id = v_task.church_id;

    insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
    select subscription.user_id, 'church_schedule_verified', 'Church schedule available',
      'Service times are now available for a church you follow.',
      format('/churches/%s', v_task.church_id),
      jsonb_build_object('churchId', v_task.church_id, 'reviewId', v_task.id)
    from app.church_subscriptions subscription
    where subscription.church_id = v_task.church_id;
  else
    update app.churches
    set is_active = false, directory_verification_status = 'closed',
      directory_verified_at = now(), directory_verified_by = v_admin_id,
      schedule_verified_at = null, schedule_verified_by = null
    where id = v_task.church_id;

    insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
    select subscription.user_id, 'church_closed', 'Church subscription removed',
      'A church you followed was confirmed closed and has been removed from your subscriptions.',
      null, jsonb_build_object('churchId', v_task.church_id, 'reviewId', v_task.id)
    from app.church_subscriptions subscription
    where subscription.church_id = v_task.church_id;

    delete from app.church_subscriptions where church_id = v_task.church_id;
  end if;

  update app.church_schedule_review_tasks
  set status = 'completed', outcome = p_decision,
    completion_reason = nullif(btrim(p_reason), ''), completed_by = v_admin_id,
    completed_at = now()
  where id = v_task.id;

  return jsonb_build_object('reviewId', v_task.id, 'churchId', v_task.church_id, 'outcome', p_decision);
end;
$$;

revoke all on function api.review_church_schedule_task(uuid, text, jsonb, jsonb, text)
from public, anon;
grant execute on function api.review_church_schedule_task(uuid, text, jsonb, jsonb, text)
to authenticated, service_role;

create or replace function api.admin_create_church(
  p_church jsonb,
  p_service_times jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_church_id uuid;
  v_name text := nullif(btrim(p_church ->> 'name'), '');
  v_address_line_1 text := nullif(btrim(p_church ->> 'address_line_1'), '');
  v_postal_code text := nullif(btrim(p_church ->> 'postal_code'), '');
  v_city text := nullif(btrim(p_church ->> 'city'), '');
  v_country_code text := nullif(upper(btrim(p_church ->> 'country_code')), '');
  v_timezone text := nullif(btrim(p_church ->> 'timezone'), '');
begin
  if v_admin_id is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;
  if not app.is_current_user_admin() then raise exception 'FORBIDDEN' using errcode = 'P0001'; end if;

  if v_name is null or v_address_line_1 is null or v_city is null
    or v_country_code is null or v_timezone is null
    or (p_church ->> 'latitude') is null or (p_church ->> 'longitude') is null then
    raise exception 'INVALID_CHURCH_DETAILS' using errcode = 'P0001';
  end if;

  if jsonb_typeof(p_service_times) <> 'array'
    or jsonb_array_length(p_service_times) = 0
    or not ('mass' = any(array(select item ->> 'service_type' from jsonb_array_elements(p_service_times) item))) then
    raise exception 'INCOMPLETE_CHURCH_SERVICE_TIMES' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from app.churches church
    where church.is_active
      and lower(church.name) = lower(v_name)
      and lower(church.address_line_1) = lower(v_address_line_1)
      and church.postal_code is not distinct from v_postal_code
  ) then
    raise exception 'CHURCH_ALREADY_EXISTS' using errcode = 'P0001';
  end if;

  insert into app.churches (
    diocese_id, name, address_line_1, address_line_2, city, region_name,
    postal_code, country_code, timezone, latitude, longitude,
    is_active, directory_verification_status, directory_verified_at,
    directory_verified_by, schedule_verified_at, schedule_verified_by
  )
  values (
    nullif(p_church ->> 'diocese_id', '')::uuid,
    v_name,
    v_address_line_1,
    nullif(btrim(p_church ->> 'address_line_2'), ''),
    v_city,
    nullif(btrim(p_church ->> 'region_name'), ''),
    v_postal_code,
    v_country_code::char(2),
    v_timezone,
    (p_church ->> 'latitude')::numeric,
    (p_church ->> 'longitude')::numeric,
    true, 'verified', now(), v_admin_id, now(), v_admin_id
  )
  returning id into v_church_id;

  insert into app.church_service_times (church_id, service_type, weekday, starts_at, ends_at)
  select distinct on (proposed.service_type, proposed.weekday, proposed.starts_at)
    v_church_id, proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at
  from jsonb_to_recordset(p_service_times) as proposed(
    service_type text, weekday smallint, starts_at time, ends_at time
  )
  order by proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at nulls last;

  return jsonb_build_object('churchId', v_church_id);
end;
$$;

revoke all on function api.admin_create_church(jsonb, jsonb) from public, anon;
grant execute on function api.admin_create_church(jsonb, jsonb)
to authenticated, service_role;
