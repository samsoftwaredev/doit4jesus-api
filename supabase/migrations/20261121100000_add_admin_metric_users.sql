-- Lets administrators see which accounts sit behind each admin app metric.
-- Definitions mirror api.get_admin_app_metrics so a list always matches its card.

create or replace function api.get_admin_metric_users(
  p_metric text,
  p_filter text default 'all',
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
  v_now timestamptz := now();
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if p_metric not in (
    'total_users', 'dau', 'wau', 'mau', 'signups_7d', 'signups_30d',
    'retention_d1', 'retention_d7', 'retention_d30', 'signup_to_active',
    'profile_setup', 'first_practice_7d', 'churn', 'rosary_completion'
  ) or p_filter not in ('all', 'yes', 'no') then
    raise exception 'INVALID_ADMIN_METRIC' using errcode = 'P0001';
  end if;

  with user_activity as materialized (
    select
      user_record.id,
      user_record.email::text as email,
      min(profile.display_name)::text as display_name,
      min(profile.username)::text as username,
      user_record.created_at as signup_at,
      count(activity.id) as activity_count,
      min(activity.created_at) as first_activity_at,
      max(activity.created_at) as last_activity_at,
      coalesce(bool_or(profile.profile_setup_completed_at is not null), false)
        as onboarding_completed,
      count(activity.id) filter (where activity.activity_code = 'ROSARY')
        as rosary_started_count,
      count(activity.id) filter (
        where activity.activity_code = 'ROSARY' and activity.completed_at is not null
      ) as rosary_completed_count,
      coalesce(bool_or(activity.created_at >= v_now - interval '24 hours'), false) as active_last_day,
      coalesce(bool_or(activity.created_at >= v_now - interval '7 days'), false) as active_last_week,
      coalesce(bool_or(activity.created_at >= v_now - interval '30 days'), false) as active_last_month,
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
    left join app.user_profiles profile on profile.user_id = user_record.id
    left join competition.spiritual_activities activity
      on activity.user_id = user_record.id
      and activity.verification_status in ('self_reported', 'verified')
    where user_record.deleted_at is null
    group by user_record.id, user_record.email, user_record.created_at
  ),
  scoped as (
    select
      ua.*,
      -- in_scope: who the card counts. positive: the yes/no split (null = no split).
      case p_metric
        when 'total_users' then true
        when 'dau' then ua.active_last_day
        when 'wau' then ua.active_last_week
        when 'mau' then ua.active_last_month
        when 'signups_7d' then ua.signup_at >= v_now - interval '7 days'
        when 'signups_30d' then ua.signup_at >= v_now - interval '30 days'
        when 'retention_d1' then ua.signup_at <= v_now - interval '2 days'
        when 'retention_d7' then ua.signup_at <= v_now - interval '8 days'
        when 'retention_d30' then ua.signup_at <= v_now - interval '31 days'
        when 'signup_to_active' then true
        when 'profile_setup' then true
        when 'first_practice_7d' then ua.signup_at <= v_now - interval '7 days'
        when 'churn' then ua.signup_at <= v_now - interval '30 days'
        when 'rosary_completion' then ua.rosary_started_count > 0
      end as in_scope,
      case p_metric
        when 'retention_d1' then ua.retained_day_1
        when 'retention_d7' then ua.retained_day_7
        when 'retention_d30' then ua.retained_day_30
        when 'signup_to_active' then ua.activity_count > 0
        when 'profile_setup' then ua.onboarding_completed
        when 'first_practice_7d' then
          coalesce(ua.first_activity_at >= ua.signup_at
            and ua.first_activity_at < ua.signup_at + interval '7 days', false)
        when 'churn' then not ua.active_last_month
        when 'rosary_completion' then ua.rosary_completed_count > 0
        else null
      end as positive
    from user_activity ua
  ),
  in_scope as (
    select * from scoped where in_scope
  ),
  filtered as (
    select * from in_scope
    where p_filter = 'all'
      or (p_filter = 'yes' and positive is true)
      or (p_filter = 'no' and positive is not true)
  ),
  page as (
    select * from filtered
    order by
      case when p_metric in ('signups_7d', 'signups_30d', 'total_users') then signup_at end desc nulls last,
      last_activity_at desc nulls last,
      signup_at desc
    limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'metric', p_metric,
    'filter', p_filter,
    'total', (select count(*) from filtered),
    'scopeTotal', (select count(*) from in_scope),
    'positiveTotal', (select count(*) from in_scope where positive is true),
    'hasPositiveSplit', p_metric in (
      'retention_d1', 'retention_d7', 'retention_d30', 'signup_to_active',
      'profile_setup', 'first_practice_7d', 'churn', 'rosary_completion'
    ),
    'users', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', page.id,
          'email', page.email,
          'displayName', page.display_name,
          'username', page.username,
          'signedUpAt', page.signup_at,
          'lastActivityAt', page.last_activity_at,
          'firstActivityAt', page.first_activity_at,
          'activityCount', page.activity_count,
          'rosariesStarted', page.rosary_started_count,
          'rosariesCompleted', page.rosary_completed_count,
          'profileSetupComplete', page.onboarding_completed,
          'positive', page.positive
        )
        order by
          case when p_metric in ('signups_7d', 'signups_30d', 'total_users') then page.signup_at end desc nulls last,
          page.last_activity_at desc nulls last,
          page.signup_at desc
      )
      from page
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function api.get_admin_metric_users(text, text, integer, integer)
from public, anon;
grant execute on function api.get_admin_metric_users(text, text, integer, integer)
to authenticated, service_role;

notify pgrst, 'reload schema';
