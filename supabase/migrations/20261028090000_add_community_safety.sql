create table app.user_blocks (
  blocker_id uuid not null references app.users(id) on delete cascade,
  blocked_user_id uuid not null references app.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_user_id)
);

create index user_blocks_blocked_user_idx
  on app.user_blocks (blocked_user_id, blocker_id);

create table app.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references app.users(id) on delete cascade,
  target_type text not null,
  target_user_id uuid references app.users(id) on delete cascade,
  prayer_intention_id uuid references prayer.prayer_intentions(id) on delete cascade,
  event_id uuid references app.events(id) on delete cascade,
  target_owner_id uuid not null references app.users(id) on delete cascade,
  reason text not null,
  details text,
  status text not null default 'open',
  admin_notes text,
  reviewed_by uuid references app.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint content_reports_target_type_check
    check (target_type in ('user', 'prayer_intention', 'event')),
  constraint content_reports_reason_check
    check (reason in (
      'harassment', 'threats_hate', 'sexual_exploitative', 'privacy',
      'scam_impersonation', 'infringement', 'spam_manipulation', 'other'
    )),
  constraint content_reports_status_check
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  constraint content_reports_details_check
    check (details is null or char_length(details) between 1 and 2000),
  constraint content_reports_single_target_check check (
    (target_type = 'user' and target_user_id is not null and prayer_intention_id is null and event_id is null)
    or (target_type = 'prayer_intention' and target_user_id is null and prayer_intention_id is not null and event_id is null)
    or (target_type = 'event' and target_user_id is null and prayer_intention_id is null and event_id is not null)
  ),
  constraint content_reports_review_state_check check (
    (status = 'open' and reviewed_by is null and reviewed_at is null)
    or (status <> 'open' and reviewed_by is not null and reviewed_at is not null)
  ),
  constraint content_reports_not_self_check check (reporter_id <> target_owner_id)
);

create index content_reports_admin_queue_idx
  on app.content_reports (status, created_at desc, id desc);
create index content_reports_reporter_idx
  on app.content_reports (reporter_id, created_at desc);
create index content_reports_target_owner_idx
  on app.content_reports (target_owner_id, created_at desc);

create trigger trg_content_reports_updated_at
before update on app.content_reports
for each row execute function platform.set_updated_at();

alter table app.user_blocks enable row level security;
alter table app.content_reports enable row level security;

revoke all on app.user_blocks, app.content_reports from anon, authenticated;
grant select, insert, delete on app.user_blocks to authenticated;
grant select, insert, update on app.content_reports to authenticated;
grant all on app.user_blocks, app.content_reports to service_role;

create policy user_blocks_manage_own
on app.user_blocks for all to authenticated
using (blocker_id = (select auth.uid()))
with check (blocker_id = (select auth.uid()));

create policy user_blocks_select_admin
on app.user_blocks for select to authenticated
using (app.is_current_user_admin());

create policy content_reports_insert_own
on app.content_reports for insert to authenticated
with check (reporter_id = (select auth.uid()));

create policy content_reports_select_admin
on app.content_reports for select to authenticated
using (app.is_current_user_admin());

create policy content_reports_update_admin
on app.content_reports for update to authenticated
using (app.is_current_user_admin())
with check (app.is_current_user_admin());

create or replace function app.users_are_blocked(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from app.user_blocks block
    where (block.blocker_id = p_first and block.blocked_user_id = p_second)
       or (block.blocker_id = p_second and block.blocked_user_id = p_first)
  );
$$;

revoke all on function app.users_are_blocked(uuid, uuid) from public;
grant execute on function app.users_are_blocked(uuid, uuid) to authenticated, service_role;

create or replace function app.prepare_content_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.reporter_id <> auth.uid() and not app.is_current_user_admin() then
    raise exception 'Report owner does not match authenticated user.' using errcode = '42501';
  end if;

  if new.target_type = 'user' then
    new.target_owner_id := new.target_user_id;
  elsif new.target_type = 'prayer_intention' then
    select intention.creator_id into new.target_owner_id
    from prayer.prayer_intentions intention
    where intention.id = new.prayer_intention_id;
  elsif new.target_type = 'event' then
    select event.creator_id into new.target_owner_id
    from app.events event
    where event.id = new.event_id;
  end if;

  if new.target_owner_id is null then
    raise exception 'Report target was not found.' using errcode = 'P0002';
  end if;
  if new.reporter_id = new.target_owner_id then
    raise exception 'Users cannot report their own content.' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger trg_prepare_content_report
before insert on app.content_reports
for each row execute function app.prepare_content_report();

create or replace function app.apply_user_block()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from app.friend_requests request
  where request.status = 'pending'
    and ((request.requester_id = new.blocker_id and request.recipient_id = new.blocked_user_id)
      or (request.requester_id = new.blocked_user_id and request.recipient_id = new.blocker_id));

  delete from app.friendships friendship
  where friendship.user_low_id = least(new.blocker_id, new.blocked_user_id)
    and friendship.user_high_id = greatest(new.blocker_id, new.blocked_user_id);
  return new;
end;
$$;

create trigger trg_apply_user_block
after insert on app.user_blocks
for each row execute function app.apply_user_block();

create or replace function app.reject_blocked_friend_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'pending' and app.users_are_blocked(new.requester_id, new.recipient_id) then
    raise exception 'Friend requests are unavailable for blocked accounts.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger trg_reject_blocked_friend_request
before insert or update on app.friend_requests
for each row execute function app.reject_blocked_friend_request();

create policy user_profiles_hide_blocked
on app.user_profiles as restrictive for select to authenticated
using (
  user_id = (select auth.uid())
  or app.is_current_user_admin()
  or not app.users_are_blocked((select auth.uid()), user_id)
);

create policy prayer_intentions_hide_blocked
on prayer.prayer_intentions as restrictive for select to authenticated
using (
  creator_id = (select auth.uid())
  or app.is_current_user_admin()
  or not app.users_are_blocked((select auth.uid()), creator_id)
);

create policy events_hide_blocked
on app.events as restrictive for select to authenticated
using (
  creator_id = (select auth.uid())
  or app.is_current_user_admin()
  or not app.users_are_blocked((select auth.uid()), creator_id)
);

create policy friendships_hide_blocked
on app.friendships as restrictive for select to authenticated
using (not app.users_are_blocked(user_low_id, user_high_id));

create policy friend_requests_hide_blocked
on app.friend_requests as restrictive for select to authenticated
using (not app.users_are_blocked(requester_id, recipient_id));

create policy leaderboard_entries_hide_blocked
on competition.leaderboard_entries as restrictive for select to authenticated
using (
  user_id = (select auth.uid())
  or app.is_current_user_admin()
  or not app.users_are_blocked((select auth.uid()), user_id)
);

create or replace view prayer.prayer_intention_cards
with (security_barrier = true)
as
select
  intention.id,
  intention.title,
  intention.description,
  intention.symbol,
  intention.reviewed_at as approved_at,
  intention.expires_at,
  intention.created_at,
  profile.display_name as creator_display_name,
  profile.avatar_url as creator_avatar_url,
  profile.country_code as creator_country_code,
  (
    select count(*)::bigint
    from prayer.prayer_intention_prayers intention_prayer
    where intention_prayer.intention_id = intention.id
  ) as prayer_count,
  intention.creator_id
from prayer.prayer_intentions intention
join app.user_profiles profile on profile.user_id = intention.creator_id
where intention.status = 'visible'
  and intention.expires_at > now()
  and not app.users_are_blocked(auth.uid(), intention.creator_id);

revoke all on prayer.prayer_intention_cards from anon, authenticated;
grant select on prayer.prayer_intention_cards to authenticated, service_role;

create or replace view app.event_cards
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
  (select count(*)::integer from app.event_views event_view where event_view.event_id = event_record.id) as view_count,
  event_record.creator_id
from app.events event_record
where event_record.status = 'active'
  and event_record.reviewed_at + make_interval(days => event_record.lifespan_days) > now()
  and not app.users_are_blocked(auth.uid(), event_record.creator_id);

revoke all on app.event_cards from anon, authenticated;
grant select on app.event_cards to authenticated, service_role;

create or replace function api.search_users(
  p_query text,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  username varchar,
  avatar_url text,
  title varchar,
  relationship_state text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := lower(trim(p_query));
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if v_query !~ '^[a-z0-9_]{4,30}$' then
    raise exception 'INVALID_USER_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  return query
  with matched_profiles as (
    select
      profile.user_id,
      profile.username::varchar as username,
      profile.avatar_url,
      profile.title,
      case
        when lower(profile.username::text) = v_query then 0
        when strpos(lower(profile.username::text), v_query) = 1 then 1
        else 2
      end as match_rank
    from app.user_profiles profile
    join app.users user_record
      on user_record.id = profile.user_id
      and user_record.status = 'active'
      and user_record.deleted_at is null
    where profile.user_id <> v_user_id
      and profile.username is not null
      and not app.users_are_blocked(v_user_id, profile.user_id)
      and lower(profile.username::text) like
        '%' || replace(v_query, '_', chr(92) || '_') || '%'
        escape chr(92)
  )
  select
    profile.username,
    profile.avatar_url,
    profile.title,
    case
      when exists (
        select 1 from app.friendships friendship
        where friendship.user_low_id = least(v_user_id, profile.user_id)
          and friendship.user_high_id = greatest(v_user_id, profile.user_id)
      ) then 'friends'
      when exists (
        select 1 from app.friend_requests request_record
        where request_record.requester_id = v_user_id
          and request_record.recipient_id = profile.user_id
          and request_record.status = 'pending'
      ) then 'outgoingPending'
      when exists (
        select 1 from app.friend_requests request_record
        where request_record.requester_id = profile.user_id
          and request_record.recipient_id = v_user_id
          and request_record.status = 'pending'
      ) then 'incomingPending'
      else 'none'
    end as relationship_state
  from matched_profiles profile
  order by profile.match_rank, lower(profile.username::text), profile.user_id
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function api.search_users(text, integer, integer) from public, anon;
grant execute on function api.search_users(text, integer, integer) to authenticated, service_role;

comment on table app.user_blocks is
  'User-controlled blocks. Insertion removes pending requests and friendships.';
comment on table app.content_reports is
  'Safety reports for users, prayer intentions, and events with administrator review state.';
