-- Church discovery by postal code, per-church reminder subscriptions, and
-- administrator schedule verification for Visit Jesus in the Tabernacle.

create extension if not exists pg_trgm with schema extensions;

create or replace function app.normalize_diocese_name(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select regexp_replace(
    replace(
      replace(
        regexp_replace(
          lower(btrim(coalesce(p_name, ''))),
          '^(roman catholic )?(archdiocese|diocese|archeparchy|eparchy) of ',
          ''
        ),
        'saint ',
        'st '
      ),
      'saint-',
      'st-'
    ),
    '[^a-z0-9]+',
    '',
    'g'
  );
$$;

revoke all on function app.normalize_diocese_name(text)
from public, anon, authenticated;

alter table app.dioceses
  add column if not exists search_key text generated always as (
    app.normalize_diocese_name(name)
  ) stored;

create index if not exists dioceses_search_key_idx
on app.dioceses (search_key);

create table app.postal_codes (
  postal_code varchar(5) primary key,
  primary_city varchar(150),
  region_codes text[] not null default '{}'::text[],
  latitude numeric(9,6) not null,
  longitude numeric(9,6) not null,
  timezone varchar(100) not null,
  diocese_status text not null,
  zcta_source_year integer not null,
  city_source_year integer not null,
  diocese_source_year integer not null,
  timezone_source_release varchar(40) not null,
  imported_at timestamptz not null default now(),
  constraint postal_codes_format_check check (postal_code ~ '^[0-9]{5}$'),
  constraint postal_codes_latitude_check check (latitude between -90 and 90),
  constraint postal_codes_longitude_check check (longitude between -180 and 180)
);

create table app.postal_code_cities (
  postal_code varchar(5) not null references app.postal_codes(postal_code) on delete cascade,
  city_name varchar(150) not null,
  city_label varchar(180),
  city_geoid varchar(20),
  region_code varchar(10),
  overlap_percent numeric(9,6),
  city_status varchar(60) not null,
  is_primary boolean not null default false,
  primary key (postal_code, city_name, region_code)
);

create index postal_code_cities_postal_primary_idx
on app.postal_code_cities (postal_code, is_primary desc, overlap_percent desc);

create table app.postal_code_dioceses (
  postal_code varchar(5) not null references app.postal_codes(postal_code) on delete cascade,
  diocese_id uuid references app.dioceses(id) on delete set null,
  label varchar(160) not null,
  match_status varchar(40) not null,
  primary key (postal_code, label)
);

create index postal_code_dioceses_diocese_idx
on app.postal_code_dioceses (diocese_id, postal_code)
where diocese_id is not null;

alter table app.churches
  add column if not exists source varchar(100),
  add column if not exists source_id varchar(200),
  add column if not exists source_release varchar(80),
  add column if not exists source_confidence numeric(8,7),
  add column if not exists directory_verification_status text not null default 'verified',
  add column if not exists directory_verified_at timestamptz,
  add column if not exists directory_verified_by uuid references app.users(id) on delete set null,
  add column if not exists schedule_verified_at timestamptz,
  add column if not exists schedule_verified_by uuid references app.users(id) on delete set null;

update app.churches church
set
  directory_verification_status = case when church.is_active then 'verified' else 'closed' end,
  directory_verified_at = case when church.is_active then coalesce(church.directory_verified_at, church.created_at) else church.directory_verified_at end,
  schedule_verified_at = case
    when exists (
      select 1 from app.church_service_times service_time
      where service_time.church_id = church.id
    ) then coalesce(church.schedule_verified_at, church.updated_at)
    else church.schedule_verified_at
  end;

alter table app.churches
  add constraint churches_directory_verification_status_check
    check (directory_verification_status in ('candidate', 'verified', 'closed')),
  add constraint churches_directory_active_check
    check (
      (directory_verification_status = 'closed' and not is_active)
      or (directory_verification_status <> 'closed' and is_active)
    ),
  add constraint churches_source_identity_check
    check ((source is null) = (source_id is null));

create unique index churches_source_identity_key
on app.churches (source, source_id)
where source is not null and source_id is not null;

create index churches_name_search_trgm
on app.churches using gin (lower(name) extensions.gin_trgm_ops)
where is_active;

create index churches_address_search_trgm
on app.churches using gin (lower(address_line_1) extensions.gin_trgm_ops)
where is_active;

create index churches_postal_code_idx
on app.churches (postal_code, name)
where is_active;

create table app.church_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app.users(id) on delete cascade,
  church_id uuid not null references app.churches(id) on delete cascade,
  notification_time time not null default '08:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint church_subscriptions_user_church_key unique (user_id, church_id),
  constraint church_subscriptions_notification_time_check check (notification_time = '08:00')
);

create index church_subscriptions_church_idx
on app.church_subscriptions (church_id, created_at);

create table app.church_subscription_service_types (
  subscription_id uuid not null references app.church_subscriptions(id) on delete cascade,
  service_type text not null,
  primary key (subscription_id, service_type),
  constraint church_subscription_service_types_value_check
    check (service_type in ('mass', 'confession', 'adoration'))
);

create table app.church_subscription_weekdays (
  subscription_id uuid not null references app.church_subscriptions(id) on delete cascade,
  weekday smallint not null,
  primary key (subscription_id, weekday),
  constraint church_subscription_weekdays_value_check check (weekday between 0 and 6)
);

create table app.church_schedule_review_tasks (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references app.churches(id) on delete cascade,
  requested_by uuid references app.users(id) on delete set null,
  status text not null default 'pending',
  outcome text,
  completion_reason text,
  completed_by uuid references app.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint church_schedule_review_tasks_status_check
    check (status in ('pending', 'completed')),
  constraint church_schedule_review_tasks_outcome_check
    check (outcome is null or outcome in ('verified', 'closed')),
  constraint church_schedule_review_tasks_completion_check
    check (
      (status = 'pending' and outcome is null and completed_at is null and completed_by is null)
      or (status = 'completed' and outcome is not null and completed_at is not null and completed_by is not null)
    )
);

create unique index church_schedule_review_tasks_one_pending_idx
on app.church_schedule_review_tasks (church_id)
where status = 'pending';

create index church_schedule_review_tasks_status_created_idx
on app.church_schedule_review_tasks (status, created_at desc, id desc);

create table app.church_reminder_deliveries (
  subscription_id uuid not null references app.church_subscriptions(id) on delete cascade,
  local_delivery_date date not null,
  outcome text not null,
  notification_id uuid references app.notifications(id) on delete set null,
  window_starts_at timestamptz not null,
  window_ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (subscription_id, local_delivery_date),
  constraint church_reminder_deliveries_outcome_check
    check (outcome in ('processing', 'sent', 'no_events')),
  constraint church_reminder_deliveries_window_check
    check (window_ends_at > window_starts_at)
);

create trigger trg_church_subscriptions_updated_at
before update on app.church_subscriptions
for each row execute function platform.set_updated_at();

create trigger trg_church_schedule_review_tasks_updated_at
before update on app.church_schedule_review_tasks
for each row execute function platform.set_updated_at();

alter table app.postal_codes enable row level security;
alter table app.postal_code_cities enable row level security;
alter table app.postal_code_dioceses enable row level security;
alter table app.church_subscriptions enable row level security;
alter table app.church_subscription_service_types enable row level security;
alter table app.church_subscription_weekdays enable row level security;
alter table app.church_schedule_review_tasks enable row level security;
alter table app.church_reminder_deliveries enable row level security;

grant select on app.postal_codes, app.postal_code_cities, app.postal_code_dioceses to authenticated;
grant select on app.church_subscriptions, app.church_subscription_service_types,
  app.church_subscription_weekdays, app.church_schedule_review_tasks,
  app.church_reminder_deliveries to authenticated;
grant all privileges on app.postal_codes, app.postal_code_cities,
  app.postal_code_dioceses, app.church_subscriptions,
  app.church_subscription_service_types, app.church_subscription_weekdays,
  app.church_schedule_review_tasks, app.church_reminder_deliveries to service_role;

create policy postal_codes_select_authenticated
on app.postal_codes for select to authenticated using (true);

create policy postal_code_cities_select_authenticated
on app.postal_code_cities for select to authenticated using (true);

create policy postal_code_dioceses_select_authenticated
on app.postal_code_dioceses for select to authenticated using (true);

create policy church_subscriptions_select_own
on app.church_subscriptions for select to authenticated
using ((select auth.uid()) = user_id);

create policy church_subscriptions_select_admin
on app.church_subscriptions for select to authenticated
using (app.is_current_user_admin());

create policy church_subscription_service_types_select_own
on app.church_subscription_service_types for select to authenticated
using (
  exists (
    select 1 from app.church_subscriptions subscription
    where subscription.id = church_subscription_service_types.subscription_id
      and subscription.user_id = (select auth.uid())
  )
);

create policy church_subscription_weekdays_select_own
on app.church_subscription_weekdays for select to authenticated
using (
  exists (
    select 1 from app.church_subscriptions subscription
    where subscription.id = church_subscription_weekdays.subscription_id
      and subscription.user_id = (select auth.uid())
  )
);

create policy church_schedule_review_tasks_select_admin
on app.church_schedule_review_tasks for select to authenticated
using (app.is_current_user_admin());

create policy church_reminder_deliveries_select_own
on app.church_reminder_deliveries for select to authenticated
using (
  exists (
    select 1 from app.church_subscriptions subscription
    where subscription.id = church_reminder_deliveries.subscription_id
      and subscription.user_id = (select auth.uid())
  )
);

create or replace function app.mark_church_schedule_verified_on_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app.churches
  set
    directory_verification_status = 'verified',
    directory_verified_at = coalesce(directory_verified_at, now()),
    directory_verified_by = coalesce(directory_verified_by, auth.uid()),
    schedule_verified_at = now(),
    schedule_verified_by = coalesce(auth.uid(), schedule_verified_by)
  where id = new.church_id;
  return new;
end;
$$;

revoke all on function app.mark_church_schedule_verified_on_insert()
from public, anon, authenticated;

create trigger trg_church_service_time_marks_verified
after insert on app.church_service_times
for each row execute function app.mark_church_schedule_verified_on_insert();

create or replace function api.search_churches_v2(
  p_country_code text default null,
  p_city text default null,
  p_diocese text default null,
  p_postal_code text default null,
  p_diocese_id uuid default null,
  p_query text default null,
  p_radius_miles numeric default 25,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  name varchar,
  address_line_1 varchar,
  address_line_2 varchar,
  city varchar,
  region_name varchar,
  postal_code varchar,
  country_code char(2),
  diocese_id uuid,
  diocese_name varchar,
  timezone varchar,
  latitude numeric,
  longitude numeric,
  distance_miles double precision,
  directory_verification_status text,
  schedule_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(lower(btrim(p_query)), '');
  v_pattern text;
  v_postal app.postal_codes%rowtype;
  v_radius numeric := coalesce(p_radius_miles, 25);
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_country_code is null and p_city is null and p_diocese is null
    and p_postal_code is null and p_diocese_id is null and v_query is null then
    raise exception 'INVALID_CHURCH_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  if p_postal_code is not null then
    select * into v_postal
    from app.postal_codes postal
    where postal.postal_code = btrim(p_postal_code);
    if not found then
      raise exception 'POSTAL_CODE_NOT_FOUND' using errcode = 'P0001';
    end if;
  end if;

  if v_radius < 1 or v_radius > 100 or (p_query is not null and (v_query is null or char_length(v_query) > 200)) then
    raise exception 'INVALID_CHURCH_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  v_pattern := replace(
    replace(replace(coalesce(v_query, ''), chr(92), chr(92) || chr(92)), '%', chr(92) || '%'),
    '_',
    chr(92) || '_'
  );

  return query
  with matches as (
    select
      church.id,
      church.name,
      church.address_line_1,
      church.address_line_2,
      church.city,
      church.region_name,
      church.postal_code,
      church.country_code,
      church.diocese_id,
      diocese.name as diocese_name,
      church.timezone,
      church.latitude,
      church.longitude,
      case when p_postal_code is null then null::double precision else
        3958.7613 * 2 * asin(sqrt(
          power(sin(radians((church.latitude - v_postal.latitude)::double precision) / 2), 2)
          + cos(radians(v_postal.latitude::double precision))
          * cos(radians(church.latitude::double precision))
          * power(sin(radians((church.longitude - v_postal.longitude)::double precision) / 2), 2)
        ))
      end as distance_miles,
      church.directory_verification_status,
      case when church.schedule_verified_at is null then 'pending' else 'verified' end as schedule_status
    from app.churches church
    left join app.dioceses diocese on diocese.id = church.diocese_id
    where church.is_active
      and (p_country_code is null or church.country_code = upper(btrim(p_country_code))::char(2))
      and (p_city is null or lower(church.city) = lower(btrim(p_city)))
      and (p_diocese is null or lower(diocese.name) = lower(btrim(p_diocese)))
      and (p_diocese_id is null or church.diocese_id = p_diocese_id)
      and (
        v_query is null
        or lower(concat_ws(' ', church.name, church.address_line_1, church.address_line_2,
          church.city, church.region_name, church.postal_code))
          like '%' || v_pattern || '%' escape E'\\'
      )
  )
  select matches.*
  from matches
  where p_postal_code is null or matches.distance_miles <= v_radius::double precision
  order by
    matches.distance_miles asc nulls last,
    case when v_query is not null and lower(matches.name) = v_query then 0 else 1 end,
    lower(matches.name),
    matches.id
  limit greatest(1, least(coalesce(p_limit, 20), 101))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function api.search_churches_v2(text, text, text, text, uuid, text, numeric, integer, integer)
from public, anon;
grant execute on function api.search_churches_v2(text, text, text, text, uuid, text, numeric, integer, integer)
to authenticated, service_role;

create or replace function api.create_church_subscription(
  p_church_id uuid,
  p_service_types text[],
  p_notification_weekdays smallint[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_subscription_id uuid;
  v_task_id uuid;
  v_schedule_verified_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if coalesce(cardinality(p_service_types), 0) = 0
    or exists (select 1 from unnest(p_service_types) value where value not in ('mass', 'confession', 'adoration'))
    or coalesce(cardinality(p_notification_weekdays), 0) = 0
    or exists (select 1 from unnest(p_notification_weekdays) value where value < 0 or value > 6) then
    raise exception 'INVALID_CHURCH_SUBSCRIPTION' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtext(v_user_id::text), hashtext('church_subscriptions'));

  select church.schedule_verified_at into v_schedule_verified_at
  from app.churches church
  where church.id = p_church_id and church.is_active
  for update;
  if not found then
    raise exception 'CHURCH_NOT_FOUND' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from app.church_subscriptions subscription
    where subscription.user_id = v_user_id and subscription.church_id = p_church_id
  ) then
    raise exception 'CHURCH_SUBSCRIPTION_EXISTS' using errcode = 'P0001';
  end if;
  if (select count(*) from app.church_subscriptions subscription where subscription.user_id = v_user_id) >= 3 then
    raise exception 'CHURCH_SUBSCRIPTION_LIMIT' using errcode = 'P0001';
  end if;

  insert into app.church_subscriptions (user_id, church_id)
  values (v_user_id, p_church_id)
  returning id into v_subscription_id;

  insert into app.church_subscription_service_types (subscription_id, service_type)
  select v_subscription_id, value from (select distinct unnest(p_service_types) as value) values_to_insert;

  insert into app.church_subscription_weekdays (subscription_id, weekday)
  select v_subscription_id, value from (select distinct unnest(p_notification_weekdays) as value) values_to_insert;

  if v_schedule_verified_at is null then
    insert into app.church_schedule_review_tasks (church_id, requested_by)
    values (p_church_id, v_user_id)
    on conflict (church_id) where status = 'pending' do nothing
    returning id into v_task_id;

    if v_task_id is not null then
      insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
      select
        role_record.user_id,
        'church_schedule_review_requested',
        'Church schedule verification requested',
        'A subscribed church needs its operating status and worship schedule verified.',
        format('/admin/church-schedule-reviews/%s', v_task_id),
        jsonb_build_object('reviewId', v_task_id, 'churchId', p_church_id)
      from app.user_roles role_record
      where role_record.role = 'admin';
    end if;
  end if;

  return jsonb_build_object(
    'id', v_subscription_id,
    'churchId', p_church_id,
    'scheduleStatus', case when v_schedule_verified_at is null then 'pending' else 'verified' end,
    'reviewId', v_task_id
  );
end;
$$;

create or replace function api.update_church_subscription(
  p_church_id uuid,
  p_service_types text[] default null,
  p_notification_weekdays smallint[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_subscription_id uuid;
begin
  if v_user_id is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;
  if p_service_types is null and p_notification_weekdays is null then
    raise exception 'INVALID_CHURCH_SUBSCRIPTION' using errcode = 'P0001';
  end if;
  if p_service_types is not null and (
    cardinality(p_service_types) = 0
    or exists (select 1 from unnest(p_service_types) value where value not in ('mass', 'confession', 'adoration'))
  ) then raise exception 'INVALID_CHURCH_SUBSCRIPTION' using errcode = 'P0001'; end if;
  if p_notification_weekdays is not null and (
    cardinality(p_notification_weekdays) = 0
    or exists (select 1 from unnest(p_notification_weekdays) value where value < 0 or value > 6)
  ) then raise exception 'INVALID_CHURCH_SUBSCRIPTION' using errcode = 'P0001'; end if;

  select subscription.id into v_subscription_id
  from app.church_subscriptions subscription
  where subscription.user_id = v_user_id and subscription.church_id = p_church_id
  for update;
  if not found then raise exception 'CHURCH_SUBSCRIPTION_NOT_FOUND' using errcode = 'P0001'; end if;

  if p_service_types is not null then
    delete from app.church_subscription_service_types where subscription_id = v_subscription_id;
    insert into app.church_subscription_service_types (subscription_id, service_type)
    select v_subscription_id, value from (select distinct unnest(p_service_types) as value) values_to_insert;
  end if;
  if p_notification_weekdays is not null then
    delete from app.church_subscription_weekdays where subscription_id = v_subscription_id;
    insert into app.church_subscription_weekdays (subscription_id, weekday)
    select v_subscription_id, value from (select distinct unnest(p_notification_weekdays) as value) values_to_insert;
  end if;
  update app.church_subscriptions set updated_at = now() where id = v_subscription_id;

  return jsonb_build_object('id', v_subscription_id, 'churchId', p_church_id, 'updated', true);
end;
$$;

create or replace function api.delete_church_subscription(p_church_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;
  delete from app.church_subscriptions
  where user_id = v_user_id and church_id = p_church_id;
  if not found then raise exception 'CHURCH_SUBSCRIPTION_NOT_FOUND' using errcode = 'P0001'; end if;
  return jsonb_build_object('churchId', p_church_id, 'deleted', true);
end;
$$;

revoke all on function api.create_church_subscription(uuid, text[], smallint[]) from public, anon;
revoke all on function api.update_church_subscription(uuid, text[], smallint[]) from public, anon;
revoke all on function api.delete_church_subscription(uuid) from public, anon;
grant execute on function api.create_church_subscription(uuid, text[], smallint[]) to authenticated, service_role;
grant execute on function api.update_church_subscription(uuid, text[], smallint[]) to authenticated, service_role;
grant execute on function api.delete_church_subscription(uuid) to authenticated, service_role;

create or replace function api.get_my_upcoming_church_services(
  p_from timestamptz default now(),
  p_days integer default 7,
  p_church_id uuid default null,
  p_service_type text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  occurrence_id text,
  service_time_id uuid,
  church_id uuid,
  church_name varchar,
  service_type text,
  starts_at timestamptz,
  ends_at timestamptz,
  local_date date,
  local_start_time time,
  local_end_time time,
  timezone varchar
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_to timestamptz;
begin
  if v_user_id is null then raise exception 'UNAUTHENTICATED' using errcode = 'P0001'; end if;
  if p_days < 1 or p_days > 31 or (p_service_type is not null and p_service_type not in ('mass', 'confession', 'adoration')) then
    raise exception 'INVALID_CHURCH_SERVICE_QUERY' using errcode = 'P0001';
  end if;
  v_to := p_from + make_interval(days => p_days);

  return query
  with occurrences as (
    select
      service_time.id as service_time_id,
      church.id as church_id,
      church.name as church_name,
      service_time.service_type,
      service_day.local_date,
      (service_day.local_date + service_time.starts_at) at time zone church.timezone as occurrence_starts_at,
      case
        when service_time.ends_at is null then
          ((service_day.local_date + service_time.starts_at) at time zone church.timezone) + interval '1 hour'
        when service_time.ends_at > service_time.starts_at then
          (service_day.local_date + service_time.ends_at) at time zone church.timezone
        else
          (service_day.local_date + 1 + service_time.ends_at) at time zone church.timezone
      end as occurrence_ends_at,
      service_time.starts_at,
      service_time.ends_at,
      church.timezone
    from app.church_subscriptions subscription
    join app.churches church on church.id = subscription.church_id and church.is_active
    join app.church_service_times service_time on service_time.church_id = church.id
    cross join lateral generate_series(
      ((p_from at time zone church.timezone)::date - 1)::timestamp,
      ((v_to at time zone church.timezone)::date + 1)::timestamp,
      interval '1 day'
    ) generated_day
    cross join lateral (select generated_day::date as local_date) service_day
    where subscription.user_id = v_user_id
      and church.schedule_verified_at is not null
      and (p_church_id is null or church.id = p_church_id)
      and (p_service_type is null or service_time.service_type = p_service_type)
      and extract(dow from service_day.local_date)::smallint = service_time.weekday
  )
  select
    occurrence.service_time_id::text || ':' || occurrence.local_date::text,
    occurrence.service_time_id,
    occurrence.church_id,
    occurrence.church_name,
    occurrence.service_type,
    occurrence.occurrence_starts_at,
    occurrence.occurrence_ends_at,
    occurrence.local_date,
    occurrence.starts_at,
    occurrence.ends_at,
    occurrence.timezone
  from occurrences occurrence
  where occurrence.occurrence_starts_at >= p_from and occurrence.occurrence_starts_at < v_to
  order by occurrence.occurrence_starts_at, occurrence.church_id, occurrence.service_time_id
  limit greatest(1, least(coalesce(p_limit, 50), 101))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function api.get_my_upcoming_church_services(timestamptz, integer, uuid, text, integer, integer)
from public, anon;
grant execute on function api.get_my_upcoming_church_services(timestamptz, integer, uuid, text, integer, integer)
to authenticated, service_role;

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
    if jsonb_typeof(p_service_times) <> 'array' or jsonb_array_length(p_service_times) = 0 then
      raise exception 'INVALID_CHURCH_SERVICE_TIMES' using errcode = 'P0001';
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
    insert into app.church_service_times (church_id, service_type, weekday, starts_at, ends_at)
    select v_task.church_id, proposed.service_type, proposed.weekday, proposed.starts_at, proposed.ends_at
    from jsonb_to_recordset(p_service_times) as proposed(
      service_type text, weekday smallint, starts_at time, ends_at time
    );

    update app.churches
    set schedule_verified_at = now(), schedule_verified_by = v_admin_id
    where id = v_task.church_id;

    insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
    select subscription.user_id, 'church_schedule_verified', 'Church schedule available',
      'Mass, confession, and adoration times are now available for a church you follow.',
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

create or replace function app.process_due_church_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_subscription record;
  v_local_date date;
  v_window_start timestamptz;
  v_window_end timestamptz;
  v_event_count integer;
  v_counts jsonb;
  v_notification_id uuid;
  v_processed integer := 0;
begin
  for v_subscription in
    select
      subscription.id,
      subscription.user_id,
      subscription.church_id,
      church.name as church_name,
      church.timezone as church_timezone,
      profile.timezone as user_timezone
    from app.church_subscriptions subscription
    join app.churches church on church.id = subscription.church_id
      and church.is_active and church.schedule_verified_at is not null
    join app.user_profiles profile on profile.user_id = subscription.user_id
    where (now() at time zone profile.timezone)::time >= subscription.notification_time
      and exists (
        select 1 from app.church_subscription_weekdays weekday
        where weekday.subscription_id = subscription.id
          and weekday.weekday = extract(dow from (now() at time zone profile.timezone)::date)::smallint
      )
  loop
    v_local_date := (now() at time zone v_subscription.user_timezone)::date;
    v_window_start := (v_local_date + time '08:00') at time zone v_subscription.user_timezone;
    v_window_end := v_window_start + interval '7 days';

    insert into app.church_reminder_deliveries (
      subscription_id, local_delivery_date, outcome, window_starts_at, window_ends_at
    ) values (
      v_subscription.id, v_local_date, 'processing', v_window_start, v_window_end
    ) on conflict do nothing;
    if not found then continue; end if;

    select coalesce(sum(service_count), 0)::integer,
      coalesce(jsonb_object_agg(service_type, service_count), '{}'::jsonb)
    into v_event_count, v_counts
    from (
      select service_time.service_type, count(*)::integer as service_count
      from app.church_service_times service_time
      join app.church_subscription_service_types selected_type
        on selected_type.subscription_id = v_subscription.id
        and selected_type.service_type = service_time.service_type
      cross join generate_series(
        ((v_window_start at time zone v_subscription.church_timezone)::date - 1)::timestamp,
        ((v_window_end at time zone v_subscription.church_timezone)::date + 1)::timestamp,
        interval '1 day'
      ) generated_day
      where service_time.church_id = v_subscription.church_id
        and extract(dow from generated_day)::smallint = service_time.weekday
        and (generated_day::date + service_time.starts_at) at time zone v_subscription.church_timezone >= v_window_start
        and (generated_day::date + service_time.starts_at) at time zone v_subscription.church_timezone < v_window_end
      group by service_time.service_type
    ) counts;

    if v_event_count > 0 then
      insert into app.notifications (user_id, notification_type, title, body, action_url, payload)
      values (
        v_subscription.user_id,
        'church_service_digest',
        v_subscription.church_name || ' worship times',
        format('%s upcoming worship time%s in the next seven days.', v_event_count, case when v_event_count = 1 then '' else 's' end),
        format('/churches/%s', v_subscription.church_id),
        jsonb_build_object(
          'churchId', v_subscription.church_id,
          'subscriptionId', v_subscription.id,
          'windowStartsAt', v_window_start,
          'windowEndsAt', v_window_end,
          'countsByServiceType', v_counts
        )
      ) returning id into v_notification_id;

      update app.church_reminder_deliveries
      set outcome = 'sent', notification_id = v_notification_id
      where subscription_id = v_subscription.id and local_delivery_date = v_local_date;
      v_processed := v_processed + 1;
    else
      update app.church_reminder_deliveries set outcome = 'no_events'
      where subscription_id = v_subscription.id and local_delivery_date = v_local_date;
    end if;
  end loop;
  return v_processed;
end;
$$;

revoke all on function app.process_due_church_reminders()
from public, anon, authenticated;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname = 'process-church-reminder-digests';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'process-church-reminder-digests',
    '*/5 * * * *',
    'select app.process_due_church_reminders();'
  );
end;
$$;
