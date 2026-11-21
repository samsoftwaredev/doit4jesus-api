-- Bulk schedule import for administrators. One call handles one church:
-- it finds the church (by id, else name + address + postal code), then either
-- updates its service times or creates it. p_dry_run reports the outcome only.

create or replace function api.admin_import_church_schedule(
  p_church_id uuid,
  p_church jsonb,
  p_service_times jsonb,
  p_dry_run boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := auth.uid();
  v_church app.churches%rowtype;
  v_church_id uuid := p_church_id;
  v_name text := nullif(btrim(p_church ->> 'name'), '');
  v_address text := nullif(btrim(p_church ->> 'address_line_1'), '');
  v_postal text := nullif(btrim(p_church ->> 'postal_code'), '');
  v_matches integer;
  v_current jsonb;
  v_action text;
  v_review_id uuid;
begin
  if v_admin_id is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;
  if not app.is_current_user_admin() then raise exception 'FORBIDDEN' using errcode = 'P0001'; end if;

  if jsonb_typeof(p_service_times) <> 'array'
    or jsonb_array_length(p_service_times) = 0
    or not ('mass' = any(array(select item ->> 'service_type' from jsonb_array_elements(p_service_times) item))) then
    raise exception 'INCOMPLETE_CHURCH_SERVICE_TIMES' using errcode = 'P0001';
  end if;

  if v_church_id is null and v_name is not null and v_address is not null then
    select count(*), min(church.id::text)::uuid into v_matches, v_church_id
    from app.churches church
    where church.is_active
      and lower(church.name) = lower(v_name)
      and lower(church.address_line_1) = lower(v_address)
      and church.postal_code is not distinct from v_postal;
    if v_matches > 1 then
      return jsonb_build_object('action', 'ambiguous', 'matches', v_matches);
    end if;
    if v_matches = 0 then v_church_id := null; end if;
  elsif v_church_id is null then
    return jsonb_build_object('action', 'invalid', 'reason', 'A churchId, or a church name and addressLine1, is required.');
  end if;

  if v_church_id is null then
    -- Not found: it will be created; validate the required details up front.
    if v_name is null or v_address is null
      or nullif(btrim(p_church ->> 'city'), '') is null
      or nullif(btrim(p_church ->> 'country_code'), '') is null
      or nullif(btrim(p_church ->> 'timezone'), '') is null
      or (p_church ->> 'latitude') is null or (p_church ->> 'longitude') is null then
      return jsonb_build_object('action', 'invalid', 'reason', 'A new church needs name, addressLine1, city, countryCode, timezone, latitude and longitude.');
    end if;
    if not p_dry_run then
      return jsonb_build_object('action', 'create') ||
        api.admin_create_church(p_church, p_service_times);
    end if;
    return jsonb_build_object('action', 'create', 'currentServiceTimes', '[]'::jsonb);
  end if;

  select * into v_church from app.churches church where church.id = v_church_id for update;
  if not found then
    return jsonb_build_object('action', 'invalid', 'reason', 'No church exists with that churchId.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'serviceType', time_row.service_type, 'weekday', time_row.weekday,
    'startTime', to_char(time_row.starts_at, 'HH24:MI'),
    'endTime', to_char(time_row.ends_at, 'HH24:MI')
  ) order by time_row.service_type, time_row.weekday, time_row.starts_at), '[]'::jsonb)
  into v_current
  from app.church_service_times time_row where time_row.church_id = v_church_id;

  v_action := 'update';
  if p_dry_run then
    return jsonb_build_object('action', v_action, 'churchId', v_church_id,
      'churchName', v_church.name, 'currentServiceTimes', v_current);
  end if;

  update app.churches
  set
    name = coalesce(v_name, name),
    address_line_1 = coalesce(v_address, address_line_1),
    address_line_2 = case when p_church ? 'address_line_2' then nullif(btrim(p_church ->> 'address_line_2'), '') else address_line_2 end,
    city = coalesce(nullif(btrim(p_church ->> 'city'), ''), city),
    region_name = case when p_church ? 'region_name' then nullif(btrim(p_church ->> 'region_name'), '') else region_name end,
    postal_code = case when p_church ? 'postal_code' then v_postal else postal_code end,
    country_code = coalesce(nullif(upper(btrim(p_church ->> 'country_code')), '')::char(2), country_code),
    timezone = coalesce(nullif(btrim(p_church ->> 'timezone'), ''), timezone),
    latitude = case when p_church ? 'latitude' then (p_church ->> 'latitude')::numeric else latitude end,
    longitude = case when p_church ? 'longitude' then (p_church ->> 'longitude')::numeric else longitude end,
    diocese_id = case when p_church ? 'diocese_id' then nullif(p_church ->> 'diocese_id', '')::uuid else diocese_id end,
    is_active = true,
    directory_verification_status = 'verified',
    directory_verified_at = now(),
    directory_verified_by = v_admin_id,
    schedule_verified_at = now(),
    schedule_verified_by = v_admin_id
  where id = v_church_id;

  delete from app.church_service_times where church_id = v_church_id;
  insert into app.church_service_times (church_id, service_type, weekday, starts_at, ends_at)
  select distinct on (proposed.service_type, proposed.weekday, proposed.starts_at)
    v_church_id, proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at
  from jsonb_to_recordset(p_service_times) as proposed(
    service_type text, weekday smallint, starts_at time, ends_at time
  )
  order by proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at nulls last;

  -- A pending schedule review for this church is now answered.
  update app.church_schedule_review_tasks
  set status = 'completed', outcome = 'verified',
    completion_reason = 'Schedule updated by JSON import',
    completed_by = v_admin_id, completed_at = now()
  where church_id = v_church_id and status = 'pending'
  returning id into v_review_id;

  insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
  select subscription.user_id, 'church_schedule_verified', 'Church schedule available',
    'Service times are now available for a church you follow.',
    format('/churches/%s', v_church_id),
    jsonb_build_object('churchId', v_church_id, 'reviewId', v_review_id)
  from app.church_subscriptions subscription
  where subscription.church_id = v_church_id;

  return jsonb_build_object('action', v_action, 'churchId', v_church_id,
    'churchName', v_church.name, 'currentServiceTimes', v_current);
end;
$$;

revoke all on function api.admin_import_church_schedule(uuid, jsonb, jsonb, boolean)
from public, anon;
grant execute on function api.admin_import_church_schedule(uuid, jsonb, jsonb, boolean)
to authenticated, service_role;

notify pgrst, 'reload schema';
