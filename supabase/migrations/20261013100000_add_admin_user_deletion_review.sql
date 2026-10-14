-- Administrator account lookup, complete pre-deletion review, and protected
-- deletion. The review functions expose app-facing account data only; they
-- intentionally omit Auth secrets and operational delivery/idempotency logs.

create or replace function app.admin_user_deletion_preview_records(p_user_id uuid)
returns table (
  section text,
  record_type text,
  occurred_at timestamptz,
  record jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select 'community', 'notification', notification.created_at,
    jsonb_build_object('recordType', 'notification', 'record', to_jsonb(notification) - 'user_id')
  from app.notifications notification where notification.user_id = p_user_id

  union all
  select 'community', 'friend_request', request_record.created_at,
    jsonb_build_object('recordType', 'friendRequest', 'record', to_jsonb(request_record))
  from app.friend_requests request_record
  where p_user_id in (request_record.requester_id, request_record.recipient_id)

  union all
  select 'community', 'friendship', friendship.created_at,
    jsonb_build_object('recordType', 'friendship', 'record', to_jsonb(friendship))
  from app.friendships friendship
  where p_user_id in (friendship.user_low_id, friendship.user_high_id)

  union all
  select 'community', 'church_link', user_church.linked_at,
    jsonb_build_object(
      'recordType', 'churchLink',
      'record', jsonb_build_object(
        'link', to_jsonb(user_church) - 'user_id',
        'church', to_jsonb(church)
      )
    )
  from app.user_churches user_church
  join app.churches church on church.id = user_church.church_id
  where user_church.user_id = p_user_id

  union all
  select 'community', 'church_change_submission', change_request.created_at,
    jsonb_build_object('recordType', 'churchChangeSubmission', 'record', to_jsonb(change_request) - 'submitted_by')
  from app.church_change_requests change_request
  where change_request.submitted_by = p_user_id

  union all
  select 'community', 'church_change_review', change_request.reviewed_at,
    jsonb_build_object('recordType', 'churchChangeReview', 'record', to_jsonb(change_request) - 'reviewed_by')
  from app.church_change_requests change_request
  where change_request.reviewed_by = p_user_id

  union all
  select 'progress', 'spiritual_activity', activity.created_at,
    jsonb_build_object('recordType', 'spiritualActivity', 'record', to_jsonb(activity) - 'user_id' - 'idempotency_key')
  from competition.spiritual_activities activity where activity.user_id = p_user_id

  union all
  select 'progress', 'point_ledger', ledger.created_at,
    jsonb_build_object('recordType', 'pointLedger', 'record', to_jsonb(ledger) - 'user_id' - 'idempotency_key')
  from competition.point_ledger ledger where ledger.user_id = p_user_id

  union all
  select 'progress', 'challenge_assignment', assignment.created_at,
    jsonb_build_object('recordType', 'challengeAssignment', 'record', to_jsonb(assignment) - 'user_id')
  from competition.user_challenge_assignments assignment where assignment.user_id = p_user_id

  union all
  select 'progress', 'challenge_progress_event', event_record.occurred_at,
    jsonb_build_object('recordType', 'challengeProgressEvent', 'record', to_jsonb(event_record) - 'idempotency_key')
  from competition.challenge_progress_events event_record
  left join competition.user_challenge_assignments assignment on assignment.id = event_record.assignment_id
  left join competition.spiritual_activities activity on activity.id = event_record.activity_id
  where assignment.user_id = p_user_id or activity.user_id = p_user_id

  union all
  select 'progress', 'user_badge', badge.earned_at,
    jsonb_build_object('recordType', 'userBadge', 'record', to_jsonb(badge) - 'user_id')
  from competition.user_badges badge where badge.user_id = p_user_id

  union all
  select 'progress', 'badge_share', share.created_at,
    jsonb_build_object('recordType', 'badgeShare', 'record', to_jsonb(share))
  from competition.badge_shares share
  join competition.user_badges badge on badge.id = share.user_badge_id
  where badge.user_id = p_user_id

  union all
  select 'progress', 'badge_progress', progress.updated_at,
    jsonb_build_object('recordType', 'badgeProgress', 'record', to_jsonb(progress) - 'user_id')
  from competition.user_badge_progress progress where progress.user_id = p_user_id

  union all
  select 'progress', 'badge_requirement_progress', progress.updated_at,
    jsonb_build_object('recordType', 'badgeRequirementProgress', 'record', to_jsonb(progress) - 'user_id')
  from competition.user_badge_requirement_progress progress where progress.user_id = p_user_id

  union all
  select 'progress', 'virtue', virtue.updated_at,
    jsonb_build_object('recordType', 'virtue', 'record', to_jsonb(virtue) - 'user_id')
  from competition.user_virtues virtue where virtue.user_id = p_user_id

  union all
  select 'progress', 'virtue_event', event_record.created_at,
    jsonb_build_object('recordType', 'virtueEvent', 'record', to_jsonb(event_record) - 'user_id' - 'idempotency_key')
  from competition.virtue_events event_record where event_record.user_id = p_user_id

  union all
  select 'progress', 'demon_encounter', encounter.created_at,
    jsonb_build_object('recordType', 'demonEncounter', 'record', to_jsonb(encounter) - 'user_id')
  from competition.user_demon_encounters encounter where encounter.user_id = p_user_id

  union all
  select 'progress', 'demon_defense_assignment', assignment.created_at,
    jsonb_build_object('recordType', 'demonDefenseAssignment', 'record', to_jsonb(assignment))
  from competition.user_demon_defense_assignments assignment
  join competition.user_demon_encounters encounter on encounter.id = assignment.encounter_id
  where encounter.user_id = p_user_id

  union all
  select 'progress', 'demon_battle_event', event_record.created_at,
    jsonb_build_object('recordType', 'demonBattleEvent', 'record', to_jsonb(event_record) - 'idempotency_key')
  from competition.demon_battle_events event_record
  join competition.user_demon_encounters encounter on encounter.id = event_record.encounter_id
  where encounter.user_id = p_user_id

  union all
  select 'progress', 'metric_snapshot', snapshot.created_at,
    jsonb_build_object('recordType', 'metricSnapshot', 'record', to_jsonb(snapshot) - 'user_id')
  from competition.user_metric_snapshots snapshot where snapshot.user_id = p_user_id

  union all
  select 'progress', 'leaderboard_entry', entry.updated_at,
    jsonb_build_object('recordType', 'leaderboardEntry', 'record', to_jsonb(entry) - 'user_id')
  from competition.leaderboard_entries entry where entry.user_id = p_user_id

  union all
  select 'prayer', 'daily_scripture_completion', completion.completed_at,
    jsonb_build_object('recordType', 'dailyScriptureCompletion', 'record', to_jsonb(completion) - 'user_id')
  from prayer.daily_scripture_completions completion where completion.user_id = p_user_id

  union all
  select 'prayer', 'prayer_intention', intention.created_at,
    jsonb_build_object('recordType', 'prayerIntention', 'record', to_jsonb(intention) - 'creator_id')
  from prayer.prayer_intentions intention where intention.creator_id = p_user_id

  union all
  select 'prayer', 'prayer_intention_review', intention.reviewed_at,
    jsonb_build_object('recordType', 'prayerIntentionReview', 'record', to_jsonb(intention) - 'reviewed_by')
  from prayer.prayer_intentions intention where intention.reviewed_by = p_user_id

  union all
  select 'prayer', 'prayer_intention_prayer', intention_prayer.created_at,
    jsonb_build_object('recordType', 'prayerIntentionPrayer', 'record', to_jsonb(intention_prayer) - 'user_id')
  from prayer.prayer_intention_prayers intention_prayer where intention_prayer.user_id = p_user_id

  union all
  select 'prayer', 'prayer_intention_approval_count', approval_count.updated_at,
    jsonb_build_object('recordType', 'prayerIntentionApprovalCount', 'record', to_jsonb(approval_count) - 'user_id')
  from prayer.prayer_intention_approval_counts approval_count where approval_count.user_id = p_user_id;
$$;

revoke all on function app.admin_user_deletion_preview_records(uuid)
from public, anon, authenticated;

create or replace function api.search_admin_users(
  p_query text,
  p_limit integer default 20
)
returns table (
  id uuid,
  email text,
  status text,
  created_at timestamptz,
  display_name text,
  username text,
  is_admin boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := lower(trim(coalesce(p_query, '')));
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if char_length(v_query) < 2 or char_length(v_query) > 320 then
    raise exception 'INVALID_ADMIN_USER_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  return query
  select
    user_record.id,
    user_record.email::text,
    user_record.status,
    user_record.created_at,
    profile.display_name,
    profile.username,
    exists (
      select 1 from app.user_roles role_record
      where role_record.user_id = user_record.id and role_record.role = 'admin'
    )
  from app.users user_record
  left join app.user_profiles profile on profile.user_id = user_record.id
  where (
    (v_query ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and user_record.id = v_query::uuid)
    or (
      v_query !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      and position(v_query in lower(coalesce(user_record.email::text, ''))) > 0
    )
  )
  order by user_record.created_at desc, user_record.id
  limit greatest(1, least(coalesce(p_limit, 20), 20));
end;
$$;

create or replace function api.get_admin_user_deletion_preview(
  p_user_id uuid,
  p_section text default 'account',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user app.users%rowtype;
  v_profile app.user_profiles%rowtype;
  v_preferences app.notification_preferences%rowtype;
  v_is_admin boolean := false;
  v_rosaries bigint := 0;
  v_sections jsonb := '{}'::jsonb;
  v_records jsonb := '[]'::jsonb;
  v_record_count integer := 0;
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if p_section not in ('account', 'community', 'progress', 'prayer') then
    raise exception 'INVALID_ADMIN_USER_PREVIEW_SECTION' using errcode = 'P0001';
  end if;

  select * into v_user from app.users user_record where user_record.id = p_user_id;
  if not found then
    raise exception 'USER_ACCOUNT_NOT_FOUND' using errcode = 'P0001';
  end if;
  select * into v_profile from app.user_profiles profile where profile.user_id = p_user_id;
  select * into v_preferences from app.notification_preferences preference where preference.user_id = p_user_id;
  select exists (
    select 1 from app.user_roles role_record
    where role_record.user_id = p_user_id and role_record.role = 'admin'
  ) into v_is_admin;
  select coalesce(sum(activity.quantity), 0)::bigint into v_rosaries
  from competition.spiritual_activities activity
  where activity.user_id = p_user_id
    and activity.activity_code = 'ROSARY'
    and activity.verification_status in ('self_reported', 'verified');

  select jsonb_build_object(
    'account', 1,
    'community', count(*) filter (where section = 'community'),
    'progress', count(*) filter (where section = 'progress'),
    'prayer', count(*) filter (where section = 'prayer')
  ) into v_sections
  from app.admin_user_deletion_preview_records(p_user_id);

  if p_section <> 'account' then
    select count(*)::integer into v_record_count
    from app.admin_user_deletion_preview_records(p_user_id)
    where section = p_section;

    select coalesce(jsonb_agg(jsonb_build_object(
      'recordType', record_type,
      'occurredAt', occurred_at,
      'record', record
    ) order by occurred_at desc, record_type), '[]'::jsonb)
    into v_records
    from (
      select record_type, occurred_at, record
      from app.admin_user_deletion_preview_records(p_user_id)
      where section = p_section
      order by occurred_at desc, record_type
      limit v_limit offset v_offset
    ) page;
  end if;

  return jsonb_build_object(
    'account', to_jsonb(v_user),
    'profile', case when v_profile.user_id is null then null else to_jsonb(v_profile) end,
    'notificationPreferences', case when v_preferences.user_id is null then null else to_jsonb(v_preferences) end,
    'isProtectedAdmin', v_is_admin,
    'anonymousRosaryContribution', v_rosaries,
    'sections', v_sections,
    'section', p_section,
    'records', v_records,
    'recordCount', v_record_count
  );
end;
$$;

-- The shared mutation body remains unavailable to direct callers. This lets
-- self-service deletion and the protected administrator operation share the
-- same cascade handling without exposing a bypass for admin-account safety.
create or replace function app.delete_user_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rosaries_prayed bigint;
begin
  select coalesce(sum(activity.quantity), 0)::bigint into v_rosaries_prayed
  from competition.spiritual_activities activity
  where activity.user_id = p_user_id
    and activity.activity_code = 'ROSARY'
    and activity.verification_status in ('self_reported', 'verified');

  update app.deleted_account_rosary_totals
  set rosaries_prayed = rosaries_prayed + v_rosaries_prayed
  where singleton;

  delete from competition.demon_battle_events event_record
  using competition.user_demon_encounters encounter
  where event_record.encounter_id = encounter.id and encounter.user_id = p_user_id;

  delete from competition.challenge_progress_events progress_event
  where progress_event.activity_id in (
    select activity.id from competition.spiritual_activities activity where activity.user_id = p_user_id
  ) or progress_event.assignment_id in (
    select assignment.id from competition.user_challenge_assignments assignment where assignment.user_id = p_user_id
  );

  delete from competition.point_ledger ledger
  where ledger.activity_id in (
    select activity.id from competition.spiritual_activities activity where activity.user_id = p_user_id
  );

  delete from app.users where id = p_user_id;
  delete from auth.users where id = p_user_id;
end;
$$;

revoke all on function app.delete_user_account_data(uuid)
from public, anon, authenticated;

create or replace function api.delete_user_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if auth.uid() <> p_user_id then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if not exists (select 1 from app.users user_record where user_record.id = p_user_id) then
    raise exception 'USER_ACCOUNT_NOT_FOUND' using errcode = 'P0001';
  end if;
  perform app.delete_user_account_data(p_user_id);
end;
$$;

create or replace function api.admin_delete_user_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if not exists (select 1 from app.users user_record where user_record.id = p_user_id) then
    raise exception 'USER_ACCOUNT_NOT_FOUND' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from app.user_roles role_record
    where role_record.user_id = p_user_id and role_record.role = 'admin'
  ) then
    raise exception 'ADMIN_ACCOUNT_PROTECTED' using errcode = 'P0001';
  end if;
  perform app.delete_user_account_data(p_user_id);
end;
$$;

revoke all on function api.search_admin_users(text, integer),
  api.get_admin_user_deletion_preview(uuid, text, integer, integer),
  api.delete_user_account(uuid),
  api.admin_delete_user_account(uuid)
from public, anon;
grant execute on function api.search_admin_users(text, integer),
  api.get_admin_user_deletion_preview(uuid, text, integer, integer),
  api.delete_user_account(uuid),
  api.admin_delete_user_account(uuid)
to authenticated, service_role;

notify pgrst, 'reload schema';
