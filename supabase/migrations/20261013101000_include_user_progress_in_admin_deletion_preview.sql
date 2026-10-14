-- Add the canonical progression summary row to the administrator deletion
-- review without rewriting the already-applied review migration.

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

  with all_records as (
    select * from app.admin_user_deletion_preview_records(p_user_id)
    union all
    select
      'progress'::text,
      'user_progress'::text,
      progress.updated_at,
      jsonb_build_object('recordType', 'userProgress', 'record', to_jsonb(progress) - 'user_id')
    from competition.user_progress progress
    where progress.user_id = p_user_id
  )
  select jsonb_build_object(
    'account', 1,
    'community', count(*) filter (where section = 'community'),
    'progress', count(*) filter (where section = 'progress'),
    'prayer', count(*) filter (where section = 'prayer')
  ) into v_sections from all_records;

  if p_section <> 'account' then
    with all_records as (
      select * from app.admin_user_deletion_preview_records(p_user_id)
      union all
      select
        'progress'::text,
        'user_progress'::text,
        progress.updated_at,
        jsonb_build_object('recordType', 'userProgress', 'record', to_jsonb(progress) - 'user_id')
      from competition.user_progress progress
      where progress.user_id = p_user_id
    )
    select count(*)::integer into v_record_count
    from all_records where section = p_section;

    with all_records as (
      select * from app.admin_user_deletion_preview_records(p_user_id)
      union all
      select
        'progress'::text,
        'user_progress'::text,
        progress.updated_at,
        jsonb_build_object('recordType', 'userProgress', 'record', to_jsonb(progress) - 'user_id')
      from competition.user_progress progress
      where progress.user_id = p_user_id
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'recordType', record_type,
      'occurredAt', occurred_at,
      'record', record
    ) order by occurred_at desc, record_type), '[]'::jsonb)
    into v_records
    from (
      select record_type, occurred_at, record
      from all_records
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

revoke all on function api.get_admin_user_deletion_preview(uuid, text, integer, integer)
from public, anon;
grant execute on function api.get_admin_user_deletion_preview(uuid, text, integer, integer)
to authenticated, service_role;

notify pgrst, 'reload schema';
