-- Authenticated, moderated community events. Event address fields are an
-- event-only exception to the profile city-data rule; no profile schema or
-- profile response is changed by this feature.

create table app.events (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references app.users(id) on delete cascade,
  title varchar(160) not null,
  description text not null,
  image_url text,
  event_url text,
  event_type varchar(16) not null,
  online_url text,
  location_name varchar(160),
  address_line_1 varchar(200),
  address_line_2 varchar(200),
  city varchar(120),
  region_name varchar(120),
  postal_code varchar(32),
  country_code char(2),
  timezone text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  lifespan_days integer not null,
  audiences text[] not null,
  status varchar(16) not null default 'pending',
  reviewed_by uuid references app.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_title_not_blank_check
    check (char_length(btrim(title)) between 1 and 160),
  constraint events_description_not_blank_check
    check (char_length(btrim(description)) between 1 and 10000),
  constraint events_type_check
    check (event_type in ('online', 'physical')),
  constraint events_schedule_check check (ends_at > starts_at),
  constraint events_lifespan_days_check check (lifespan_days between 1 and 365),
  constraint events_audiences_check
    check (
      cardinality(audiences) between 1 and 3
      and audiences <@ array['all', 'youth', 'kids']::text[]
    ),
  constraint events_status_check
    check (status in ('pending', 'active', 'inactive', 'rejected')),
  constraint events_review_state_check
    check (
      (status = 'pending' and reviewed_by is null and reviewed_at is null)
      or
      (status <> 'pending' and reviewed_by is not null and reviewed_at is not null)
    ),
  constraint events_location_check
    check (
      (
        event_type = 'online'
        and online_url is not null
        and location_name is null
        and address_line_1 is null
        and address_line_2 is null
        and city is null
        and region_name is null
        and postal_code is null
        and country_code is null
      )
      or
      (
        event_type = 'physical'
        and online_url is null
        and location_name is not null
        and address_line_1 is not null
        and city is not null
        and country_code is not null
      )
    )
);

create index events_active_starts_at_idx
  on app.events (starts_at asc, id asc)
  where status = 'active';

create index events_creator_created_at_idx
  on app.events (creator_id, created_at desc, id desc);

create index events_status_created_at_idx
  on app.events (status, created_at desc, id desc);

create index events_audiences_idx on app.events using gin (audiences);

create table app.event_attendees (
  event_id uuid not null references app.events(id) on delete cascade,
  user_id uuid not null references app.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index event_attendees_user_created_at_idx
  on app.event_attendees (user_id, created_at desc);

create table app.event_views (
  event_id uuid not null references app.events(id) on delete cascade,
  user_id uuid not null references app.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table app.events enable row level security;
alter table app.event_attendees enable row level security;
alter table app.event_views enable row level security;

revoke all privileges on table app.events, app.event_attendees, app.event_views
  from anon, authenticated;

grant select on table app.events to authenticated;
grant insert (
  creator_id, title, description, image_url, event_url, event_type, online_url,
  location_name, address_line_1, address_line_2, city, region_name, postal_code,
  country_code, timezone, starts_at, ends_at, lifespan_days, audiences, status,
  reviewed_by, reviewed_at
) on table app.events to authenticated;
grant all privileges on table app.events, app.event_attendees, app.event_views
  to service_role;

create policy events_select_creator_or_admin
on app.events
for select
to authenticated
using (
  creator_id = (select auth.uid())
  or app.is_current_user_admin()
);

create policy events_insert_own_pending
on app.events
for insert
to authenticated
with check (
  creator_id = (select auth.uid())
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
);

create policy events_insert_admin_active
on app.events
for insert
to authenticated
with check (
  app.is_current_user_admin()
  and creator_id = (select auth.uid())
  and status = 'active'
  and reviewed_by = (select auth.uid())
  and reviewed_at is not null
);

-- The public event feed is a projection, rather than a direct table policy,
-- so pending and inactive submissions are never readable cross-user.
create view app.event_cards
with (security_barrier = true)
as
select
  event_record.id,
  event_record.title,
  event_record.description,
  event_record.image_url,
  event_record.event_url,
  event_record.event_type,
  event_record.online_url,
  event_record.location_name,
  event_record.address_line_1,
  event_record.address_line_2,
  event_record.city,
  event_record.region_name,
  event_record.postal_code,
  event_record.country_code,
  event_record.timezone,
  event_record.starts_at,
  event_record.ends_at,
  event_record.lifespan_days,
  event_record.audiences,
  event_record.reviewed_at as approved_at,
  event_record.reviewed_at + make_interval(days => event_record.lifespan_days) as expires_at,
  event_record.created_at,
  (select count(*)::integer from app.event_attendees attendee where attendee.event_id = event_record.id) as attendee_count,
  (select count(*)::integer from app.event_views event_view where event_view.event_id = event_record.id) as view_count
from app.events event_record
where event_record.status = 'active'
  and event_record.reviewed_at + make_interval(days => event_record.lifespan_days) > now();

create view app.my_event_summaries
with (security_barrier = true)
as
select
  event_record.id,
  event_record.title,
  event_record.description,
  event_record.image_url,
  event_record.event_url,
  event_record.event_type,
  event_record.online_url,
  event_record.location_name,
  event_record.address_line_1,
  event_record.address_line_2,
  event_record.city,
  event_record.region_name,
  event_record.postal_code,
  event_record.country_code,
  event_record.timezone,
  event_record.starts_at,
  event_record.ends_at,
  event_record.lifespan_days,
  event_record.audiences,
  event_record.status,
  event_record.reviewed_by,
  event_record.reviewed_at,
  event_record.created_at,
  event_record.reviewed_at + make_interval(days => event_record.lifespan_days) as expires_at,
  (select count(*)::integer from app.event_attendees attendee where attendee.event_id = event_record.id) as attendee_count,
  (select count(*)::integer from app.event_views event_view where event_view.event_id = event_record.id) as view_count
from app.events event_record
where event_record.creator_id = (select auth.uid());

revoke all privileges on table app.event_cards, app.my_event_summaries
  from anon, authenticated;
grant select on table app.event_cards, app.my_event_summaries to authenticated;
grant select on table app.event_cards, app.my_event_summaries to service_role;

create or replace function api.review_event(
  p_event_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reviewer_id uuid := auth.uid();
  v_event app.events%rowtype;
  v_reviewed_at timestamptz := now();
begin
  if v_reviewer_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if p_decision is null or p_decision not in ('active', 'inactive', 'rejected') then
    raise exception 'INVALID_EVENT_DECISION' using errcode = 'P0001';
  end if;

  select * into v_event
  from app.events event_record
  where event_record.id = p_event_id
  for update;

  if not found then
    raise exception 'EVENT_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_event.status = 'pending' and p_decision in ('active', 'rejected') then
    update app.events
    set
      status = p_decision,
      reviewed_by = v_reviewer_id,
      reviewed_at = v_reviewed_at,
      updated_at = v_reviewed_at
    where id = v_event.id;
  elsif v_event.status = 'active' and p_decision = 'inactive' then
    update app.events
    set status = 'inactive', updated_at = v_reviewed_at
    where id = v_event.id;
  elsif v_event.status = 'inactive' and p_decision = 'active' then
    update app.events
    set status = 'active', updated_at = v_reviewed_at
    where id = v_event.id;
  else
    raise exception 'INVALID_EVENT_STATUS_TRANSITION' using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'id', v_event.id,
    'status', p_decision,
    'reviewedAt', case when v_event.status = 'pending' then v_reviewed_at else v_event.reviewed_at end,
    'expiresAt', (case when v_event.status = 'pending' then v_reviewed_at else v_event.reviewed_at end) + make_interval(days => v_event.lifespan_days)
  );
end;
$$;

create or replace function api.record_event_view(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_view_count integer;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from app.events event_record
    where event_record.id = p_event_id
      and event_record.status = 'active'
      and event_record.reviewed_at + make_interval(days => event_record.lifespan_days) > now()
  ) then
    raise exception 'EVENT_NOT_AVAILABLE' using errcode = 'P0001';
  end if;

  insert into app.event_views (event_id, user_id)
  values (p_event_id, v_user_id)
  on conflict (event_id, user_id) do nothing;

  select count(*)::integer into v_view_count
  from app.event_views event_view
  where event_view.event_id = p_event_id;

  return jsonb_build_object('eventId', p_event_id, 'viewCount', v_view_count);
end;
$$;

create or replace function api.rsvp_to_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_inserted integer;
  v_attendee_count integer;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from app.events event_record
    where event_record.id = p_event_id
      and event_record.status = 'active'
      and event_record.reviewed_at + make_interval(days => event_record.lifespan_days) > now()
      and event_record.ends_at > now()
  ) then
    raise exception 'EVENT_NOT_AVAILABLE_FOR_RSVP' using errcode = 'P0001';
  end if;

  insert into app.event_attendees (event_id, user_id)
  values (p_event_id, v_user_id)
  on conflict (event_id, user_id) do nothing;
  get diagnostics v_inserted = row_count;

  select count(*)::integer into v_attendee_count
  from app.event_attendees attendee
  where attendee.event_id = p_event_id;

  return jsonb_build_object(
    'eventId', p_event_id,
    'rsvpCreated', v_inserted = 1,
    'attendeeCount', v_attendee_count
  );
end;
$$;

create or replace function api.cancel_event_rsvp(p_event_id uuid)
returns void
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

  delete from app.event_attendees
  where event_id = p_event_id and user_id = v_user_id;
end;
$$;

revoke all on function api.review_event(uuid, text) from public, anon;
revoke all on function api.record_event_view(uuid) from public, anon;
revoke all on function api.rsvp_to_event(uuid) from public, anon;
revoke all on function api.cancel_event_rsvp(uuid) from public, anon;
grant execute on function api.review_event(uuid, text),
  api.record_event_view(uuid), api.rsvp_to_event(uuid), api.cancel_event_rsvp(uuid)
  to authenticated, service_role;
