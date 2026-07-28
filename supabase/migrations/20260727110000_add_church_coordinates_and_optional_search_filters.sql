-- Church coordinates are required catalogue data. Existing local church rows
-- are backfilled from their matching app-city only so this migration can be
-- applied before the refreshed seed replaces those values with church-level
-- coordinates.

alter table app.churches
  add column if not exists latitude numeric(9,6),
  add column if not exists longitude numeric(9,6);

update app.churches church_record
set
  latitude = city_record.latitude,
  longitude = city_record.longitude
from app.cities city_record
where church_record.latitude is null
  and church_record.longitude is null
  and church_record.country_code = city_record.country_code
  and lower(church_record.city) = lower(city_record.name);

do $$
begin
  if exists (
    select 1
    from app.churches
    where latitude is null or longitude is null
  ) then
    raise exception 'Church coordinates must be populated before this migration can complete.';
  end if;
end;
$$;

alter table app.churches
  alter column latitude set not null,
  alter column longitude set not null,
  add constraint churches_latitude_check check (latitude between -90 and 90),
  add constraint churches_longitude_check check (longitude between -180 and 180);

-- A caller can filter by any one of country, city, or diocese. Whenever more
-- than one is supplied, every supplied filter must match the same church.
drop function if exists api.search_churches(text, text, text, integer, integer);

create function api.search_churches(
  p_country_code text default null,
  p_city text default null,
  p_diocese text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  name varchar,
  city varchar,
  region_name varchar,
  country_code char(2),
  diocese_name varchar,
  timezone varchar,
  latitude numeric,
  longitude numeric
)
language sql
stable
set search_path = ''
as $$
  select
    church_record.id,
    church_record.name,
    church_record.city,
    church_record.region_name,
    church_record.country_code,
    diocese_record.name as diocese_name,
    church_record.timezone,
    church_record.latitude,
    church_record.longitude
  from app.churches church_record
  left join app.dioceses diocese_record
    on diocese_record.id = church_record.diocese_id
  where church_record.is_active
    and (
      p_country_code is null
      or church_record.country_code = upper(trim(p_country_code))::char(2)
    )
    and (
      p_city is null
      or lower(church_record.city) = lower(trim(p_city))
    )
    and (
      p_diocese is null
      or lower(diocese_record.name) = lower(trim(p_diocese))
    )
  order by church_record.name, church_record.id
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- Approval remains an atomic operation. Create-church requests now persist the
-- validated latitude and longitude supplied with the proposed church.
create or replace function api.review_church_change_request(
  p_request_id uuid,
  p_decision text,
  p_rejection_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reviewer_id uuid := auth.uid();
  v_request app.church_change_requests%rowtype;
  v_church_id uuid;
begin
  if v_reviewer_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if p_decision is null or p_decision not in ('approved', 'rejected') then
    raise exception 'INVALID_CHURCH_CHANGE_DECISION' using errcode = 'P0001';
  end if;

  select *
  into v_request
  from app.church_change_requests request_record
  where request_record.id = p_request_id
  for update;

  if not found then
    raise exception 'CHURCH_CHANGE_REQUEST_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'CHURCH_CHANGE_REQUEST_NOT_PENDING' using errcode = 'P0001';
  end if;

  if p_decision = 'rejected' then
    update app.church_change_requests
    set
      status = 'rejected',
      reviewed_by = v_reviewer_id,
      reviewed_at = now(),
      rejection_reason = nullif(trim(p_rejection_reason), '')
    where id = v_request.id;

    return jsonb_build_object(
      'requestId', v_request.id,
      'status', 'rejected',
      'churchId', v_request.church_id
    );
  end if;

  if jsonb_array_length(v_request.proposed_service_times) = 0 then
    raise exception 'INVALID_CHURCH_SERVICE_TIMES' using errcode = 'P0001';
  end if;

  if v_request.request_type = 'create_church' then
    insert into app.churches (
      diocese_id,
      name,
      address_line_1,
      address_line_2,
      city,
      region_name,
      postal_code,
      country_code,
      timezone,
      latitude,
      longitude
    )
    select
      proposed.diocese_id,
      proposed.name,
      proposed.address_line_1,
      proposed.address_line_2,
      proposed.city,
      proposed.region_name,
      proposed.postal_code,
      proposed.country_code,
      proposed.timezone,
      proposed.latitude,
      proposed.longitude
    from jsonb_to_record(v_request.proposed_church) as proposed(
      diocese_id uuid,
      name varchar,
      address_line_1 varchar,
      address_line_2 varchar,
      city varchar,
      region_name varchar,
      postal_code varchar,
      country_code char(2),
      timezone varchar,
      latitude numeric,
      longitude numeric
    )
    returning id into v_church_id;
  else
    select church_record.id
    into v_church_id
    from app.churches church_record
    where church_record.id = v_request.church_id
    for update;

    if not found then
      raise exception 'CHURCH_NOT_FOUND' using errcode = 'P0001';
    end if;

    delete from app.church_service_times
    where church_id = v_church_id;
  end if;

  insert into app.church_service_times (
    church_id,
    service_type,
    weekday,
    starts_at,
    ends_at
  )
  select
    v_church_id,
    proposed.service_type,
    proposed.weekday,
    proposed.start_time,
    proposed.end_time
  from jsonb_to_recordset(v_request.proposed_service_times) as proposed(
    service_type text,
    weekday smallint,
    start_time time,
    end_time time
  );

  update app.church_change_requests
  set
    status = 'approved',
    reviewed_by = v_reviewer_id,
    reviewed_at = now(),
    rejection_reason = null
  where id = v_request.id;

  return jsonb_build_object(
    'requestId', v_request.id,
    'status', 'approved',
    'churchId', v_church_id
  );
end;
$$;

grant execute on function api.search_churches(text, text, text, integer, integer)
to authenticated, service_role;

grant execute on function api.review_church_change_request(uuid, text, text)
to authenticated, service_role;
