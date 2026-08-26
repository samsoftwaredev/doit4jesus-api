-- Community prayer intentions are intentionally separate from prayer events:
-- they contain moderated, user-authored text rather than aggregate activity.

create table prayer.prayer_intentions (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references app.users(id) on delete cascade,
  title varchar(120) not null,
  description varchar(250) not null,
  symbol varchar(32),
  status varchar(16) not null default 'pending',
  reviewed_by uuid references app.users(id) on delete set null,
  reviewed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  constraint prayer_intentions_title_not_blank_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint prayer_intentions_description_not_blank_check
    check (char_length(btrim(description)) between 1 and 250),
  constraint prayer_intentions_symbol_check
    check (
      symbol is null
      or symbol in ('candle', 'cross', 'dove', 'olive_branch')
    ),
  constraint prayer_intentions_status_check
    check (status in ('pending', 'visible', 'rejected')),
  constraint prayer_intentions_review_state_check
    check (
      (status = 'pending'
        and reviewed_by is null
        and reviewed_at is null
        and expires_at is null)
      or
      (status in ('visible', 'rejected')
        and reviewed_by is not null
        and reviewed_at is not null
        and expires_at is not null
        and expires_at > reviewed_at)
    )
);

create index idx_prayer_intentions_creator_created
  on prayer.prayer_intentions (creator_id, created_at desc);

create index idx_prayer_intentions_status_reviewed
  on prayer.prayer_intentions (status, reviewed_at desc);

create index idx_prayer_intentions_expiry
  on prayer.prayer_intentions (expires_at)
  where expires_at is not null;

-- The count survives one-month source-row retention so badge thresholds always
-- mean approved intentions over the user's lifetime.
create table prayer.prayer_intention_approval_counts (
  user_id uuid primary key references app.users(id) on delete cascade,
  approved_count integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint prayer_intention_approval_counts_nonnegative_check
    check (approved_count >= 0)
);

alter table prayer.prayer_intentions enable row level security;
alter table prayer.prayer_intention_approval_counts enable row level security;

revoke all privileges on table prayer.prayer_intentions
  from anon, authenticated;
revoke all privileges on table prayer.prayer_intention_approval_counts
  from anon, authenticated;

grant select on table prayer.prayer_intentions to authenticated;
grant insert (creator_id, title, description, symbol)
  on table prayer.prayer_intentions to authenticated;
grant all privileges on table prayer.prayer_intentions,
  prayer.prayer_intention_approval_counts to service_role;

create policy prayer_intentions_select_creator_or_admin
on prayer.prayer_intentions
for select
to authenticated
using (
  creator_id = (select auth.uid())
  or app.is_current_user_admin()
);

create policy prayer_intentions_insert_own_pending
on prayer.prayer_intentions
for insert
to authenticated
with check (
  creator_id = (select auth.uid())
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and expires_at is null
);

-- This projection is the only cross-user read surface for intentions. A
-- visible intention is an explicit consent to show its creator's card profile.
create view prayer.prayer_intention_cards
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
  profile.country_code as creator_country_code
from prayer.prayer_intentions intention
join app.user_profiles profile on profile.user_id = intention.creator_id
where intention.status = 'visible'
  and intention.expires_at > now();

revoke all privileges on table prayer.prayer_intention_cards
  from anon, authenticated;
grant select on table prayer.prayer_intention_cards to authenticated;
grant select on table prayer.prayer_intention_cards to service_role;

insert into competition.badge_definitions (
  id,
  code,
  name,
  description,
  category,
  rarity,
  icon_url,
  locked_icon_url,
  requirement_type,
  requirement_value,
  rules,
  points_reward,
  is_repeatable,
  is_shareable,
  is_active
)
values
  (
    '80000000-0000-4000-8000-000000000012',
    'PRAYER_INTENTION_1',
    'First Intention',
    'Share one community prayer intention approved by an administrator.',
    'prayer',
    'common',
    '/badges/prayer-intention-1.png',
    '/badges/locked.png',
    'approved_prayer_intentions',
    1,
    '{"approvedIntentions":1}'::jsonb,
    0,
    false,
    true,
    true
  ),
  (
    '80000000-0000-4000-8000-000000000013',
    'PRAYER_INTENTION_3',
    'Faithful Intercessor',
    'Share three community prayer intentions approved by an administrator.',
    'prayer',
    'uncommon',
    '/badges/prayer-intention-3.png',
    '/badges/locked.png',
    'approved_prayer_intentions',
    3,
    '{"approvedIntentions":3}'::jsonb,
    0,
    false,
    true,
    true
  ),
  (
    '80000000-0000-4000-8000-000000000014',
    'PRAYER_INTENTION_7',
    'Prayer Advocate',
    'Share seven community prayer intentions approved by an administrator.',
    'prayer',
    'rare',
    '/badges/prayer-intention-7.png',
    '/badges/locked.png',
    'approved_prayer_intentions',
    7,
    '{"approvedIntentions":7}'::jsonb,
    0,
    false,
    true,
    true
  )
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  rarity = excluded.rarity,
  icon_url = excluded.icon_url,
  locked_icon_url = excluded.locked_icon_url,
  requirement_type = excluded.requirement_type,
  requirement_value = excluded.requirement_value,
  rules = excluded.rules,
  points_reward = excluded.points_reward,
  is_repeatable = excluded.is_repeatable,
  is_shareable = excluded.is_shareable,
  is_active = excluded.is_active;

create or replace function competition.award_prayer_intention_badges()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approved_count integer;
  v_badge record;
  v_user_badge_id uuid;
begin
  if old.status = 'visible' or new.status <> 'visible' then
    return new;
  end if;

  insert into prayer.prayer_intention_approval_counts as approval_count (
    user_id,
    approved_count
  )
  values (new.creator_id, 1)
  on conflict (user_id) do update
  set
    approved_count = approval_count.approved_count + 1,
    updated_at = now()
  returning approved_count into v_approved_count;

  -- Keep the existing badge API's progress data current for all three goals.
  insert into competition.user_badge_progress (
    user_id,
    badge_id,
    current_value,
    required_value
  )
  select
    new.creator_id,
    badge.id,
    v_approved_count,
    badge.requirement_value
  from competition.badge_definitions badge
  where badge.code in (
    'PRAYER_INTENTION_1',
    'PRAYER_INTENTION_3',
    'PRAYER_INTENTION_7'
  )
  on conflict (user_id, badge_id) do update
  set
    current_value = excluded.current_value,
    required_value = excluded.required_value;

  for v_badge in
    select id, code, name, requirement_value
    from competition.badge_definitions
    where code in (
      'PRAYER_INTENTION_1',
      'PRAYER_INTENTION_3',
      'PRAYER_INTENTION_7'
    )
      and is_active
      and requirement_value = v_approved_count
  loop
    v_user_badge_id := null;

    insert into competition.user_badges (
      user_id,
      badge_id,
      source_type,
      source_id,
      sequence_number,
      metadata
    )
    select
      new.creator_id,
      v_badge.id,
      'prayer_intention_approval',
      new.id,
      1,
      jsonb_build_object(
        'prayerIntentionId', new.id,
        'approvedIntentions', v_approved_count
      )
    where not exists (
      select 1
      from competition.user_badges user_badge
      where user_badge.user_id = new.creator_id
        and user_badge.badge_id = v_badge.id
    )
    returning id into v_user_badge_id;

    if v_user_badge_id is not null then
      insert into app.notifications (
        user_id,
        notification_type,
        title,
        body,
        action_url,
        payload
      )
      values (
        new.creator_id,
        'prayer_intention_badge_earned',
        format('Badge earned: %s', v_badge.name),
        'An administrator approved your prayer intention.',
        '/badges',
        jsonb_build_object(
          'badgeCode', v_badge.code,
          'userBadgeId', v_user_badge_id,
          'prayerIntentionId', new.id,
          'approvedIntentions', v_approved_count
        )
      );
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_prayer_intention_badges
on prayer.prayer_intentions;

create trigger trg_prayer_intention_badges
after update of status on prayer.prayer_intentions
for each row
execute function competition.award_prayer_intention_badges();

revoke all on function competition.award_prayer_intention_badges()
  from public, anon, authenticated;

create or replace function api.review_prayer_intention(
  p_intention_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reviewer_id uuid := auth.uid();
  v_intention prayer.prayer_intentions%rowtype;
  v_reviewed_at timestamptz := now();
begin
  if v_reviewer_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if p_decision is null or p_decision not in ('visible', 'rejected') then
    raise exception 'INVALID_PRAYER_INTENTION_DECISION' using errcode = 'P0001';
  end if;

  select *
  into v_intention
  from prayer.prayer_intentions intention
  where intention.id = p_intention_id
  for update;

  if not found then
    raise exception 'PRAYER_INTENTION_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_intention.status <> 'pending' then
    raise exception 'PRAYER_INTENTION_NOT_PENDING' using errcode = 'P0001';
  end if;

  update prayer.prayer_intentions
  set
    status = p_decision,
    reviewed_by = v_reviewer_id,
    reviewed_at = v_reviewed_at,
    expires_at = v_reviewed_at + interval '1 month'
  where id = v_intention.id;

  return jsonb_build_object(
    'id', v_intention.id,
    'status', p_decision,
    'reviewedAt', v_reviewed_at,
    'expiresAt', v_reviewed_at + interval '1 month'
  );
end;
$$;

revoke all on function api.review_prayer_intention(uuid, text)
  from public, anon;
grant execute on function api.review_prayer_intention(uuid, text)
  to authenticated, service_role;

-- The cleanup runs every fifteen minutes. Pending intentions intentionally do
-- not have an expiry until an administrator reviews them; visible and rejected
-- intentions are deleted one month after that review.
create or replace function prayer.delete_expired_prayer_intentions()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from prayer.prayer_intentions
  where expires_at is not null
    and expires_at <= now();
$$;

revoke all on function prayer.delete_expired_prayer_intentions()
  from public, anon, authenticated;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname = 'delete-expired-prayer-intentions'
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'delete-expired-prayer-intentions',
    '*/15 * * * *',
    $cron$
      select prayer.delete_expired_prayer_intentions();
    $cron$
  );
end;
$$;
