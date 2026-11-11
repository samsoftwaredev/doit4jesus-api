-- Administrators are notified when someone follows a church without a verified
-- schedule. The in-app notification pointed at a route that does not exist in
-- the web app; link it to the Admin Center schedule reviews instead, matching
-- the administrator email and queue bell. No other behavior changes.

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
        '/dashboard?tab=admin&panel=churches&churchView=schedules',
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

revoke all on function api.create_church_subscription(uuid, text[], smallint[]) from public, anon;
grant execute on function api.create_church_subscription(uuid, text[], smallint[]) to authenticated, service_role;
