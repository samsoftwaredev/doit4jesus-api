-- Run against the local seeded database. Every data change is rolled back.
-- Following a church without a verified schedule must notify administrators.
begin;

do $$
declare
  v_user_one uuid := '11111111-1111-4111-8111-111111111111';
  v_user_two uuid := '22222222-2222-4222-8222-222222222222';
  v_unscheduled uuid;
  v_verified uuid;
  v_result jsonb;
  v_admins integer;
  v_tasks integer;
  v_notifications integer;
  v_emails integer;
begin
  select count(*) into v_admins from app.user_roles where role = 'admin';
  if v_admins = 0 then raise exception 'Expected at least one seeded administrator'; end if;

  insert into app.churches (
    name, address_line_1, city, region_name, postal_code, country_code,
    timezone, latitude, longitude
  )
  values (
    'SQL Test Unscheduled Parish', '1 Test Way', 'Austin', 'TX', '78701',
    'US', 'America/Chicago', 30.27, -97.74
  )
  returning id into v_unscheduled;

  insert into app.churches (
    name, address_line_1, city, region_name, postal_code, country_code,
    timezone, latitude, longitude, schedule_verified_at
  )
  values (
    'SQL Test Verified Parish', '2 Test Way', 'Austin', 'TX', '78701',
    'US', 'America/Chicago', 30.27, -97.74, now()
  )
  returning id into v_verified;

  -- First follower of an unscheduled church queues one review and notifies every administrator.
  perform set_config('request.jwt.claim.sub', v_user_one::text, true);
  v_result := api.create_church_subscription(
    v_unscheduled, array['mass', 'confession', 'adoration'], array[0, 1, 2, 3, 4, 5, 6]::smallint[]
  );
  if v_result ->> 'scheduleStatus' <> 'pending' or v_result ->> 'reviewId' is null then
    raise exception 'Expected a pending schedule review, got %', v_result;
  end if;

  select count(*) into v_tasks from app.church_schedule_review_tasks
  where church_id = v_unscheduled and status = 'pending';
  if v_tasks <> 1 then raise exception 'Expected 1 pending review, found %', v_tasks; end if;

  select count(*) into v_notifications from app.notifications
  where notification_type = 'church_schedule_review_requested'
    and payload ->> 'churchId' = v_unscheduled::text
    and action_url = '/dashboard?tab=admin&panel=churches&churchView=schedules';
  if v_notifications <> v_admins then
    raise exception 'Expected % administrator notifications, found %', v_admins, v_notifications;
  end if;

  select count(*) into v_emails from app.admin_notification_email_jobs
  where category = 'church_schedule_review' and source_id = (v_result ->> 'reviewId')::uuid;
  if v_emails <> v_admins then
    raise exception 'Expected % administrator emails, found %', v_admins, v_emails;
  end if;

  -- A second follower of the same church does not create a duplicate review or notification.
  perform set_config('request.jwt.claim.sub', v_user_two::text, true);
  perform api.create_church_subscription(
    v_unscheduled, array['mass'], array[0]::smallint[]
  );
  select count(*) into v_tasks from app.church_schedule_review_tasks
  where church_id = v_unscheduled and status = 'pending';
  if v_tasks <> 1 then raise exception 'Expected the pending review to stay unique, found %', v_tasks; end if;
  select count(*) into v_notifications from app.notifications
  where notification_type = 'church_schedule_review_requested'
    and payload ->> 'churchId' = v_unscheduled::text;
  if v_notifications <> v_admins then
    raise exception 'Expected no extra administrator notifications, found %', v_notifications;
  end if;

  -- Following the same church again succeeds without a new subscription, review, or notification.
  v_result := api.create_church_subscription(
    v_unscheduled, array['mass'], array[0]::smallint[]
  );
  if (v_result ->> 'alreadySubscribed')::boolean is not true then
    raise exception 'Expected an idempotent repeat follow, got %', v_result;
  end if;
  if (select count(*) from app.church_subscriptions
      where user_id = v_user_two and church_id = v_unscheduled) <> 1 then
    raise exception 'Expected exactly one subscription after a repeat follow';
  end if;

  -- Following a church that already has a verified schedule queues nothing.
  perform api.create_church_subscription(
    v_verified, array['mass'], array[0]::smallint[]
  );
  if exists (select 1 from app.church_schedule_review_tasks where church_id = v_verified) then
    raise exception 'Expected no review for a verified schedule';
  end if;
end
$$;

rollback;
