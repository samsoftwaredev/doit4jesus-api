-- Schedule updates are a repeatable community contribution. Each approved
-- update grants its submitter an independently recorded badge instance.

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
values (
  '80000000-0000-4000-8000-000000000011',
  'CHURCH_SCHEDULE_STEWARD',
  'Church Schedule Steward',
  'Keep a church''s worship schedule current. Earned for every approved schedule update.',
  'community',
  'common',
  '/badges/community-helper.png',
  '/badges/locked.png',
  'approved_church_schedule_update',
  1,
  '{"requestType":"schedule_update"}'::jsonb,
  0,
  true,
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

create or replace function competition.award_approved_church_schedule_badge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_badge_id uuid;
  v_sequence_number integer;
  v_user_badge_id uuid;
begin
  if new.request_type <> 'schedule_update'
    or old.status = 'approved'
    or new.status <> 'approved' then
    return new;
  end if;

  select badge.id
  into v_badge_id
  from competition.badge_definitions badge
  where badge.code = 'CHURCH_SCHEDULE_STEWARD'
    and badge.is_active;

  if v_badge_id is null then
    raise exception 'CHURCH_SCHEDULE_BADGE_NOT_CONFIGURED' using errcode = 'P0001';
  end if;

  -- user_badges makes repeatable awards unique by (user, badge, sequence).
  -- This transaction-scoped lock prevents concurrent approvals from choosing
  -- the same next sequence number for the same user's badge.
  perform pg_advisory_xact_lock(
    hashtext(new.submitted_by::text),
    hashtext(v_badge_id::text)
  );

  select coalesce(max(user_badge.sequence_number), 0) + 1
  into v_sequence_number
  from competition.user_badges user_badge
  where user_badge.user_id = new.submitted_by
    and user_badge.badge_id = v_badge_id;

  insert into competition.user_badges (
    user_id,
    badge_id,
    source_type,
    source_id,
    sequence_number,
    metadata
  )
  values (
    new.submitted_by,
    v_badge_id,
    'church_schedule_update',
    new.id,
    v_sequence_number,
    jsonb_build_object(
      'changeRequestId', new.id,
      'churchId', new.church_id
    )
  )
  returning id into v_user_badge_id;

  insert into app.notifications (
    user_id,
    notification_type,
    title,
    body,
    action_url,
    payload
  )
  values (
    new.submitted_by,
    'church_schedule_update_reward',
    'Church Schedule Steward badge earned',
    'Your church schedule update was approved. Thank you for keeping Mass, confession, and adoration times current.',
    format('/churches/%s', new.church_id),
    jsonb_build_object(
      'badgeCode', 'CHURCH_SCHEDULE_STEWARD',
      'userBadgeId', v_user_badge_id,
      'sequenceNumber', v_sequence_number,
      'changeRequestId', new.id,
      'churchId', new.church_id
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_church_schedule_change_badge
on app.church_change_requests;

create trigger trg_church_schedule_change_badge
after update of status on app.church_change_requests
for each row
execute function competition.award_approved_church_schedule_badge();

revoke all on function competition.award_approved_church_schedule_badge()
from public, anon, authenticated;
