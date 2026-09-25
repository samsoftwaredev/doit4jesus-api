-- Delete Auth and application records in one transaction. The caller may
-- delete only their own account unless they hold the app administrator role.

-- A deleted administrator can no longer remain the reviewer of an otherwise
-- valid visible/rejected intention. The review timestamp remains as audit
-- history, while the deleted reviewer's identity is removed by the FK.
alter table prayer.prayer_intentions
  drop constraint prayer_intentions_review_state_check,
  add constraint prayer_intentions_review_state_check
  check (
    (status = 'pending'
      and reviewed_by is null
      and reviewed_at is null
      and expires_at is null)
    or
    (status in ('visible', 'rejected')
      and reviewed_at is not null
      and expires_at is not null
      and expires_at > reviewed_at)
  );

create or replace function api.delete_user_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid := auth.uid();
  v_rosaries_prayed bigint;
begin
  if v_caller_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if v_caller_id <> p_user_id and not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select coalesce(sum(activity.quantity), 0)::bigint
  into v_rosaries_prayed
  from competition.spiritual_activities activity
  where activity.user_id = p_user_id
    and activity.activity_code = 'ROSARY'
    and activity.verification_status in ('self_reported', 'verified');

  update app.deleted_account_rosary_totals
  set rosaries_prayed = rosaries_prayed + v_rosaries_prayed
  where singleton;

  -- Remove records that reference user-owned rows through non-cascading FKs
  -- before deleting app.users and its cascading descendants.
  delete from competition.demon_battle_events event_record
  using competition.user_demon_encounters encounter
  where event_record.encounter_id = encounter.id
    and encounter.user_id = p_user_id;

  delete from competition.challenge_progress_events progress_event
  where progress_event.activity_id in (
    select activity.id
    from competition.spiritual_activities activity
    where activity.user_id = p_user_id
  )
  or progress_event.assignment_id in (
    select assignment.id
    from competition.user_challenge_assignments assignment
    where assignment.user_id = p_user_id
  );

  delete from competition.point_ledger ledger
  where ledger.activity_id in (
    select activity.id
    from competition.spiritual_activities activity
    where activity.user_id = p_user_id
  );

  delete from prayer.prayer_events prayer_event
  where prayer_event.activity_id in (
    select activity.id
    from competition.spiritual_activities activity
    where activity.user_id = p_user_id
  );

  delete from app.users where id = p_user_id;
  delete from auth.users where id = p_user_id;
end;
$$;

revoke all on function api.delete_user_account(uuid) from public, anon;
grant execute on function api.delete_user_account(uuid) to authenticated, service_role;

-- This RPC was introduced by the prior migration but is superseded by the
-- authorized target-user RPC above. Keep it unavailable to client roles.
revoke all on function api.delete_current_user_account() from public, anon, authenticated;
