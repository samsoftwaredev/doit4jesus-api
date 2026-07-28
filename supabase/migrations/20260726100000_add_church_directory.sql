-- Church catalogue, recurring service schedules, personal church links, and
-- moderated community-submitted changes. Live service state is intentionally
-- computed by the API from these local weekly times, never persisted.

create table app.dioceses (
  id uuid primary key default gen_random_uuid(),
  country_code char(2) not null references app.countries(code),
  name varchar(160) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint dioceses_country_name_key unique (country_code, name)
);

create table app.churches (
  id uuid primary key default gen_random_uuid(),
  diocese_id uuid references app.dioceses(id) on delete set null,
  name varchar(200) not null,
  address_line_1 varchar(200) not null,
  address_line_2 varchar(200),
  city varchar(150) not null,
  region_name varchar(150),
  postal_code varchar(32),
  country_code char(2) not null references app.countries(code),
  timezone varchar(100) not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_churches_country_city
  on app.churches (country_code, city, name)
  where is_active;

create index idx_churches_diocese
  on app.churches (diocese_id, name)
  where is_active;

create table app.church_service_times (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references app.churches(id) on delete cascade,
  service_type text not null,
  weekday smallint not null,
  starts_at time not null,
  ends_at time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint church_service_times_type_check
    check (service_type in ('mass', 'confession', 'adoration')),
  constraint church_service_times_weekday_check
    check (weekday between 0 and 6),
  constraint church_service_times_unique
    unique (church_id, service_type, weekday, starts_at)
);

create index idx_church_service_times_church_weekday
  on app.church_service_times (church_id, weekday, starts_at);

create table app.user_churches (
  user_id uuid not null references app.users(id) on delete cascade,
  church_id uuid not null references app.churches(id) on delete cascade,
  is_primary boolean not null default false,
  linked_at timestamptz not null default now(),
  primary key (user_id, church_id)
);

create unique index user_churches_one_primary_idx
  on app.user_churches (user_id)
  where is_primary;

create table app.user_roles (
  user_id uuid primary key references app.users(id) on delete cascade,
  role text not null,
  granted_at timestamptz not null default now(),
  constraint user_roles_role_check check (role = 'admin')
);

create table app.church_change_requests (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid not null references app.users(id) on delete cascade,
  request_type text not null,
  church_id uuid references app.churches(id) on delete cascade,
  proposed_church jsonb not null default '{}'::jsonb,
  proposed_service_times jsonb not null default '[]'::jsonb,
  notes text,
  status text not null default 'pending',
  reviewed_by uuid references app.users(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint church_change_requests_type_check
    check (request_type in ('create_church', 'schedule_update')),
  constraint church_change_requests_status_check
    check (status in ('pending', 'approved', 'rejected')),
  constraint church_change_requests_target_check
    check (
      (request_type = 'create_church' and church_id is null)
      or (request_type = 'schedule_update' and church_id is not null)
    ),
  constraint church_change_requests_proposed_church_object_check
    check (jsonb_typeof(proposed_church) = 'object'),
  constraint church_change_requests_proposed_times_array_check
    check (jsonb_typeof(proposed_service_times) = 'array')
);

create index idx_church_change_requests_status_created
  on app.church_change_requests (status, created_at desc);

create index idx_church_change_requests_submitter_created
  on app.church_change_requests (submitted_by, created_at desc);

create trigger trg_dioceses_updated_at
before update on app.dioceses
for each row execute function platform.set_updated_at();

create trigger trg_churches_updated_at
before update on app.churches
for each row execute function platform.set_updated_at();

create trigger trg_church_service_times_updated_at
before update on app.church_service_times
for each row execute function platform.set_updated_at();

create trigger trg_church_change_requests_updated_at
before update on app.church_change_requests
for each row execute function platform.set_updated_at();

alter table app.dioceses enable row level security;
alter table app.churches enable row level security;
alter table app.church_service_times enable row level security;
alter table app.user_churches enable row level security;
alter table app.user_roles enable row level security;
alter table app.church_change_requests enable row level security;

create or replace function app.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from app.user_roles role_record
    where role_record.user_id = auth.uid()
      and role_record.role = 'admin'
  );
$$;

revoke all on function app.is_current_user_admin() from public, anon;
grant execute on function app.is_current_user_admin() to authenticated, service_role;

-- All reads below are scoped by RLS. Write operations that require a
-- multi-row invariant (one primary church and moderator approval) use the
-- narrowly scoped API functions below instead of direct table writes.
grant select on
  app.dioceses,
  app.churches,
  app.church_service_times,
  app.user_churches,
  app.church_change_requests
to authenticated;

grant insert (
  submitted_by,
  request_type,
  church_id,
  proposed_church,
  proposed_service_times,
  notes
) on app.church_change_requests to authenticated;

create policy dioceses_select_authenticated
on app.dioceses
for select
to authenticated
using (true);

create policy churches_select_active_authenticated
on app.churches
for select
to authenticated
using (is_active);

create policy church_service_times_select_active_church_authenticated
on app.church_service_times
for select
to authenticated
using (
  exists (
    select 1
    from app.churches church_record
    where church_record.id = church_service_times.church_id
      and church_record.is_active
  )
);

create policy user_churches_select_own
on app.user_churches
for select
to authenticated
using (auth.uid() = user_id);

create policy church_change_requests_select_own_or_admin
on app.church_change_requests
for select
to authenticated
using (
  auth.uid() = submitted_by
  or app.is_current_user_admin()
);

create policy church_change_requests_insert_own
on app.church_change_requests
for insert
to authenticated
with check (
  auth.uid() = submitted_by
  and status = 'pending'
);

create or replace function api.search_churches(
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
  timezone varchar
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
    church_record.timezone
  from app.churches church_record
  left join app.dioceses diocese_record
    on diocese_record.id = church_record.diocese_id
  where church_record.is_active
    and (
      (p_country_code is not null and church_record.country_code = upper(trim(p_country_code))::char(2))
      or (p_city is not null and lower(church_record.city) = lower(trim(p_city)))
      or (p_diocese is not null and lower(diocese_record.name) = lower(trim(p_diocese)))
    )
  order by church_record.name, church_record.id
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function api.link_current_user_church(
  p_church_id uuid,
  p_is_primary boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_already_linked boolean;
  v_is_primary boolean;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from app.churches church_record
    where church_record.id = p_church_id
      and church_record.is_active
  ) then
    raise exception 'CHURCH_NOT_FOUND' using errcode = 'P0001';
  end if;

  select exists (
    select 1
    from app.user_churches user_church
    where user_church.user_id = v_user_id
      and user_church.church_id = p_church_id
  ) into v_already_linked;

  if p_is_primary then
    update app.user_churches
    set is_primary = false
    where user_id = v_user_id
      and is_primary;
  end if;

  insert into app.user_churches (user_id, church_id, is_primary)
  values (v_user_id, p_church_id, p_is_primary)
  on conflict (user_id, church_id) do update
  set is_primary = case
    when p_is_primary then true
    else app.user_churches.is_primary
  end
  returning is_primary into v_is_primary;

  return jsonb_build_object(
    'churchId', p_church_id,
    'isPrimary', v_is_primary,
    'created', not v_already_linked
  );
end;
$$;

create or replace function api.set_current_user_primary_church(
  p_church_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from app.user_churches user_church
    where user_church.user_id = v_user_id
      and user_church.church_id = p_church_id
  ) then
    raise exception 'CHURCH_NOT_LINKED' using errcode = 'P0001';
  end if;

  update app.user_churches
  set is_primary = false
  where user_id = v_user_id
    and is_primary;

  update app.user_churches
  set is_primary = true
  where user_id = v_user_id
    and church_id = p_church_id;

  return jsonb_build_object('churchId', p_church_id, 'isPrimary', true);
end;
$$;

create or replace function api.unlink_current_user_church(
  p_church_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  delete from app.user_churches
  where user_id = v_user_id
    and church_id = p_church_id;

  if not found then
    raise exception 'CHURCH_NOT_LINKED' using errcode = 'P0001';
  end if;

  return jsonb_build_object('churchId', p_church_id, 'unlinked', true);
end;
$$;

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
      timezone
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
      proposed.timezone
    from jsonb_to_record(v_request.proposed_church) as proposed(
      diocese_id uuid,
      name varchar,
      address_line_1 varchar,
      address_line_2 varchar,
      city varchar,
      region_name varchar,
      postal_code varchar,
      country_code char(2),
      timezone varchar
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

revoke all on function api.search_churches(text, text, text, integer, integer) from public, anon;
revoke all on function api.link_current_user_church(uuid, boolean) from public, anon;
revoke all on function api.set_current_user_primary_church(uuid) from public, anon;
revoke all on function api.unlink_current_user_church(uuid) from public, anon;
revoke all on function api.review_church_change_request(uuid, text, text) from public, anon;

grant execute on function api.search_churches(text, text, text, integer, integer) to authenticated, service_role;
grant execute on function api.link_current_user_church(uuid, boolean) to authenticated, service_role;
grant execute on function api.set_current_user_primary_church(uuid) to authenticated, service_role;
grant execute on function api.unlink_current_user_church(uuid) to authenticated, service_role;
grant execute on function api.review_church_change_request(uuid, text, text) to authenticated, service_role;
