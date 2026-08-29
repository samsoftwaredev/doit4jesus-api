-- Aggregate, privacy-preserving product-health metrics for administrators.
-- Activity-based metrics use accepted spiritual-activity records as the
-- available proxy for app activity; no private prayer text is exposed.

create or replace function api.get_admin_app_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_requesting_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_total_users bigint := 0;
  v_daily_active_users bigint := 0;
  v_weekly_active_users bigint := 0;
  v_monthly_active_users bigint := 0;
  v_signups_7d bigint := 0;
  v_signups_30d bigint := 0;
  v_d1_eligible bigint := 0;
  v_d1_retained bigint := 0;
  v_d7_eligible bigint := 0;
  v_d7_retained bigint := 0;
  v_d30_eligible bigint := 0;
  v_d30_retained bigint := 0;
  v_ever_active_users bigint := 0;
  v_onboarding_completed_users bigint := 0;
  v_first_practice_eligible bigint := 0;
  v_first_practice_within_7_days bigint := 0;
  v_churn_eligible bigint := 0;
  v_churned_users bigint := 0;
  v_rosary_started bigint := 0;
  v_rosary_completed bigint := 0;
  v_trends jsonb := '[]'::jsonb;
begin
  if v_requesting_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  with user_activity as materialized (
    select
      user_record.id,
      user_record.created_at as signup_at,
      count(activity.id) as activity_count,
      min(activity.created_at) as first_activity_at,
      coalesce(
        bool_or(profile.profile_setup_completed_at is not null),
        false
      ) as onboarding_completed,
      count(activity.id) filter (
        where activity.activity_code = 'ROSARY'
      ) as rosary_started_count,
      count(activity.id) filter (
        where activity.activity_code = 'ROSARY'
          and activity.completed_at is not null
      ) as rosary_completed_count,
      coalesce(bool_or(activity.created_at >= v_now - interval '24 hours'), false)
        as active_last_day,
      coalesce(bool_or(activity.created_at >= v_now - interval '7 days'), false)
        as active_last_week,
      coalesce(bool_or(activity.created_at >= v_now - interval '30 days'), false)
        as active_last_month,
      coalesce(bool_or(
        activity.created_at >= user_record.created_at + interval '1 day'
        and activity.created_at < user_record.created_at + interval '2 days'
      ), false) as retained_day_1,
      coalesce(bool_or(
        activity.created_at >= user_record.created_at + interval '7 days'
        and activity.created_at < user_record.created_at + interval '8 days'
      ), false) as retained_day_7,
      coalesce(bool_or(
        activity.created_at >= user_record.created_at + interval '30 days'
        and activity.created_at < user_record.created_at + interval '31 days'
      ), false) as retained_day_30
    from app.users user_record
    left join app.user_profiles profile
      on profile.user_id = user_record.id
    left join competition.spiritual_activities activity
      on activity.user_id = user_record.id
      and activity.verification_status in ('self_reported', 'verified')
    where user_record.deleted_at is null
    group by user_record.id, user_record.created_at
  )
  select
    count(*)::bigint,
    count(*) filter (where active_last_day)::bigint,
    count(*) filter (where active_last_week)::bigint,
    count(*) filter (where active_last_month)::bigint,
    count(*) filter (where signup_at >= v_now - interval '7 days')::bigint,
    count(*) filter (where signup_at >= v_now - interval '30 days')::bigint,
    count(*) filter (where signup_at <= v_now - interval '2 days')::bigint,
    count(*) filter (
      where signup_at <= v_now - interval '2 days' and retained_day_1
    )::bigint,
    count(*) filter (where signup_at <= v_now - interval '8 days')::bigint,
    count(*) filter (
      where signup_at <= v_now - interval '8 days' and retained_day_7
    )::bigint,
    count(*) filter (where signup_at <= v_now - interval '31 days')::bigint,
    count(*) filter (
      where signup_at <= v_now - interval '31 days' and retained_day_30
    )::bigint,
    count(*) filter (where activity_count > 0)::bigint,
    count(*) filter (where onboarding_completed)::bigint,
    count(*) filter (where signup_at <= v_now - interval '7 days')::bigint,
    count(*) filter (
      where signup_at <= v_now - interval '7 days'
        and first_activity_at >= signup_at
        and first_activity_at < signup_at + interval '7 days'
    )::bigint,
    count(*) filter (where signup_at <= v_now - interval '30 days')::bigint,
    count(*) filter (
      where signup_at <= v_now - interval '30 days' and not active_last_month
    )::bigint,
    coalesce(sum(rosary_started_count), 0)::bigint,
    coalesce(sum(rosary_completed_count), 0)::bigint
  into
    v_total_users,
    v_daily_active_users,
    v_weekly_active_users,
    v_monthly_active_users,
    v_signups_7d,
    v_signups_30d,
    v_d1_eligible,
    v_d1_retained,
    v_d7_eligible,
    v_d7_retained,
    v_d30_eligible,
    v_d30_retained,
    v_ever_active_users,
    v_onboarding_completed_users,
    v_first_practice_eligible,
    v_first_practice_within_7_days,
    v_churn_eligible,
    v_churned_users,
    v_rosary_started,
    v_rosary_completed
  from user_activity;

  with days as (
    select day_start
    from generate_series(
      date_trunc('day', v_now at time zone 'UTC') - interval '29 days',
      date_trunc('day', v_now at time zone 'UTC'),
      interval '1 day'
    ) as calendar(day_start)
  ),
  daily_signups as (
    select
      date_trunc('day', user_record.created_at at time zone 'UTC') as day_start,
      count(*)::bigint as total
    from app.users user_record
    where user_record.deleted_at is null
      and user_record.created_at >= (
        date_trunc('day', v_now at time zone 'UTC') - interval '29 days'
      ) at time zone 'UTC'
    group by 1
  ),
  first_activity_by_user as (
    select activity.user_id, min(activity.created_at) as first_activity_at
    from competition.spiritual_activities activity
    where activity.verification_status in ('self_reported', 'verified')
    group by activity.user_id
  ),
  daily_newly_active_users as (
    select
      date_trunc('day', first_activity_at at time zone 'UTC') as day_start,
      count(*)::bigint as total
    from first_activity_by_user
    where first_activity_at >= (
      date_trunc('day', v_now at time zone 'UTC') - interval '29 days'
    ) at time zone 'UTC'
    group by 1
  ),
  daily_active_users as (
    select
      date_trunc('day', activity.created_at at time zone 'UTC') as day_start,
      count(distinct activity.user_id)::bigint as total
    from competition.spiritual_activities activity
    where activity.verification_status in ('self_reported', 'verified')
      and activity.created_at >= (
        date_trunc('day', v_now at time zone 'UTC') - interval '29 days'
      ) at time zone 'UTC'
    group by 1
  ),
  daily_rosary_starts as (
    select
      date_trunc('day', activity.created_at at time zone 'UTC') as day_start,
      count(*)::bigint as total
    from competition.spiritual_activities activity
    where activity.activity_code = 'ROSARY'
      and activity.verification_status in ('self_reported', 'verified')
      and activity.created_at >= (
        date_trunc('day', v_now at time zone 'UTC') - interval '29 days'
      ) at time zone 'UTC'
    group by 1
  ),
  daily_rosary_completions as (
    select
      date_trunc('day', activity.completed_at at time zone 'UTC') as day_start,
      count(*)::bigint as total
    from competition.spiritual_activities activity
    where activity.activity_code = 'ROSARY'
      and activity.completed_at is not null
      and activity.verification_status in ('self_reported', 'verified')
      and activity.completed_at >= (
        date_trunc('day', v_now at time zone 'UTC') - interval '29 days'
      ) at time zone 'UTC'
    group by 1
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'date', to_char(days.day_start, 'YYYY-MM-DD'),
        'signups', coalesce(daily_signups.total, 0),
        'newlyActiveUsers', coalesce(daily_newly_active_users.total, 0),
        'dailyActiveUsers', coalesce(daily_active_users.total, 0),
        'rosariesStarted', coalesce(daily_rosary_starts.total, 0),
        'rosariesCompleted', coalesce(daily_rosary_completions.total, 0)
      )
      order by days.day_start
    ),
    '[]'::jsonb
  )
  into v_trends
  from days
  left join daily_signups using (day_start)
  left join daily_newly_active_users using (day_start)
  left join daily_active_users using (day_start)
  left join daily_rosary_starts using (day_start)
  left join daily_rosary_completions using (day_start);

  return jsonb_build_object(
    'generatedAt', v_now,
    'totalUsers', v_total_users,
    'dailyActiveUsers', v_daily_active_users,
    'weeklyActiveUsers', v_weekly_active_users,
    'monthlyActiveUsers', v_monthly_active_users,
    'signups7d', v_signups_7d,
    'signups30d', v_signups_30d,
    'retentionD1', case when v_d1_eligible = 0 then 0 else round(
      (v_d1_retained::numeric * 100) / v_d1_eligible,
      1
    ) end,
    'retentionD7', case when v_d7_eligible = 0 then 0 else round(
      (v_d7_retained::numeric * 100) / v_d7_eligible,
      1
    ) end,
    'retentionD30', case when v_d30_eligible = 0 then 0 else round(
      (v_d30_retained::numeric * 100) / v_d30_eligible,
      1
    ) end,
    'signupToActiveRate', case when v_total_users = 0 then 0 else round(
      (v_ever_active_users::numeric * 100) / v_total_users,
      1
    ) end,
    'onboardingCompletionRate', case when v_total_users = 0 then 0 else round(
      (v_onboarding_completed_users::numeric * 100) / v_total_users,
      1
    ) end,
    'firstPracticeWithin7dRate', case when v_first_practice_eligible = 0 then 0 else round(
      (v_first_practice_within_7_days::numeric * 100)
        / v_first_practice_eligible,
      1
    ) end,
    'churnRate', case when v_churn_eligible = 0 then 0 else round(
      (v_churned_users::numeric * 100) / v_churn_eligible,
      1
    ) end,
    'rosaryCompletionRate', case when v_rosary_started = 0 then 0 else round(
      (v_rosary_completed::numeric * 100) / v_rosary_started,
      1
    ) end,
    'trends', v_trends
  );
end;
$$;

revoke all on function api.get_admin_app_metrics() from public, anon;
grant execute on function api.get_admin_app_metrics() to authenticated, service_role;
