-- Each record represents one prayer offered for an approved intention. Records
-- are intentionally append-only: users may pray for the same intention more
-- than once, and there is no undo operation.

create table prayer.prayer_intention_prayers (
  id uuid primary key default gen_random_uuid(),
  intention_id uuid not null references prayer.prayer_intentions(id) on delete cascade,
  user_id uuid not null references app.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index idx_prayer_intention_prayers_intention_created
  on prayer.prayer_intention_prayers (intention_id, created_at desc);

alter table prayer.prayer_intention_prayers enable row level security;

revoke all privileges on table prayer.prayer_intention_prayers
  from anon, authenticated;
grant all privileges on table prayer.prayer_intention_prayers to service_role;

-- Recreate the public card projection with a privacy-safe aggregate. This is
-- intentionally a count only; the identities of people who prayed stay private.
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
  ) as prayer_count
from prayer.prayer_intentions intention
join app.user_profiles profile on profile.user_id = intention.creator_id
where intention.status = 'visible'
  and intention.expires_at > now();

revoke all privileges on table prayer.prayer_intention_cards
  from anon, authenticated;
grant select on table prayer.prayer_intention_cards to authenticated, service_role;

-- Current users can see their own records in every moderation state, including
-- their aggregate prayer counts. This view does not grant access to other users'
-- pending or rejected intentions.
create view prayer.my_prayer_intention_summaries
with (security_barrier = true)
as
select
  intention.id,
  intention.title,
  intention.description,
  intention.symbol,
  intention.status,
  intention.created_at,
  intention.reviewed_at,
  intention.expires_at,
  (
    select count(*)::bigint
    from prayer.prayer_intention_prayers intention_prayer
    where intention_prayer.intention_id = intention.id
  ) as prayer_count
from prayer.prayer_intentions intention
where intention.creator_id = (select auth.uid())
  and (intention.expires_at is null or intention.expires_at > now());

revoke all privileges on table prayer.my_prayer_intention_summaries
  from anon, authenticated;
grant select on table prayer.my_prayer_intention_summaries
  to authenticated, service_role;

-- Only an intention creator or administrator may resolve the list of people
-- who prayed. The view deliberately exposes only card-safe profile fields.
create view prayer.prayer_intention_prayer_participants
with (security_barrier = true)
as
select
  intention_prayer.id,
  intention_prayer.intention_id,
  intention_prayer.user_id,
  intention_prayer.created_at,
  profile.display_name,
  profile.avatar_url,
  profile.country_code
from prayer.prayer_intention_prayers intention_prayer
join prayer.prayer_intentions intention
  on intention.id = intention_prayer.intention_id
join app.user_profiles profile on profile.user_id = intention_prayer.user_id
where intention.creator_id = (select auth.uid())
  or app.is_current_user_admin();

revoke all privileges on table prayer.prayer_intention_prayer_participants
  from anon, authenticated;
grant select on table prayer.prayer_intention_prayer_participants
  to authenticated, service_role;

create or replace function api.record_prayer_intention_prayer(
  p_intention_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_prayer_id uuid;
  v_prayer_count bigint;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from prayer.prayer_intentions intention
    where intention.id = p_intention_id
      and intention.status = 'visible'
      and intention.expires_at > now()
  ) then
    raise exception 'PRAYER_INTENTION_NOT_AVAILABLE' using errcode = 'P0001';
  end if;

  insert into prayer.prayer_intention_prayers (intention_id, user_id)
  values (p_intention_id, v_user_id)
  returning id into v_prayer_id;

  select count(*)::bigint
  into v_prayer_count
  from prayer.prayer_intention_prayers intention_prayer
  where intention_prayer.intention_id = p_intention_id;

  return jsonb_build_object(
    'id', v_prayer_id,
    'intentionId', p_intention_id,
    'prayedAt', now(),
    'prayerCount', v_prayer_count
  );
end;
$$;

revoke all on function api.record_prayer_intention_prayer(uuid)
  from public, anon, authenticated;
grant execute on function api.record_prayer_intention_prayer(uuid)
  to authenticated, service_role;
