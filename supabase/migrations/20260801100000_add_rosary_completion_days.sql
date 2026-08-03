-- Add the complete calendar for the selected month to rosary completion.
-- Dates remain grouped in the authenticated user's configured timezone.

create or replace function api.get_my_rosary_completion(
  p_year integer default null,
  p_month smallint default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, app, competition, platform, api
as $$
declare
  v_user_id uuid := auth.uid();
  v_created_at timestamptz;
  v_timezone text;
  v_today date;
  v_join_date date;
  v_year integer;
  v_selected_month smallint;
  v_year_start date;
  v_year_end_exclusive date;
  v_year_eligible_start date;
  v_year_eligible_end date;
  v_year_completed_days integer := 0;
  v_year_eligible_days integer := 0;
  v_year_percentage numeric(7, 2) := 0;
  v_completed_dates date[] := '{}'::date[];
  v_months jsonb;
  v_days jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  select user_record.created_at, profile.timezone
  into v_created_at, v_timezone
  from app.users user_record
  join app.user_profiles profile on profile.user_id = user_record.id
  where user_record.id = v_user_id
    and user_record.deleted_at is null;

  if not found then
    raise exception 'USER_PROFILE_NOT_FOUND';
  end if;

  v_timezone := coalesce(nullif(trim(v_timezone), ''), 'UTC');

  begin
    v_today := (now() at time zone v_timezone)::date;
    v_join_date := (v_created_at at time zone v_timezone)::date;
  exception
    when invalid_parameter_value then
      raise exception 'USER_TIMEZONE_INVALID';
  end;

  if p_year is not null and (p_year < 1 or p_year > 9998) then
    raise exception 'INVALID_SELECTED_YEAR';
  end if;

  if p_month is not null and (p_month < 1 or p_month > 12) then
    raise exception 'INVALID_SELECTED_MONTH';
  end if;

  v_year := coalesce(p_year, extract(year from v_today)::integer);
  v_selected_month := coalesce(p_month, extract(month from v_today)::smallint);
  v_year_start := make_date(v_year, 1, 1);
  v_year_end_exclusive := (v_year_start + interval '1 year')::date;

  select coalesce(
    array_agg(distinct (activity.completed_at at time zone v_timezone)::date),
    '{}'::date[]
  )
  into v_completed_dates
  from competition.spiritual_activities activity
  where activity.user_id = v_user_id
    and activity.activity_code = 'ROSARY'
    and activity.completed_at is not null
    and activity.verification_status in ('self_reported', 'verified')
    and activity.completed_at >= (v_year_start::timestamp at time zone v_timezone)
    and activity.completed_at < (v_year_end_exclusive::timestamp at time zone v_timezone);

  v_year_eligible_start := greatest(v_year_start, v_join_date);
  v_year_eligible_end := least(v_year_end_exclusive - 1, v_today);

  if v_year_eligible_end >= v_year_eligible_start then
    v_year_eligible_days := (v_year_eligible_end - v_year_eligible_start) + 1;

    select count(*)::integer
    into v_year_completed_days
    from unnest(v_completed_dates) completed_date
    where completed_date between v_year_eligible_start and v_year_eligible_end;

    v_year_percentage := round(
      (v_year_completed_days::numeric * 100) / v_year_eligible_days,
      2
    );
  end if;

  with month_calendar as (
    select
      month_number::smallint as month_number,
      make_date(v_year, month_number, 1) as month_start,
      (make_date(v_year, month_number, 1) + interval '1 month')::date as month_end_exclusive,
      (array[
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ])[month_number] as month_name
    from generate_series(1, 12) month_number
  ), month_windows as (
    select
      month_number,
      month_name,
      greatest(month_start, v_year_start, v_join_date) as eligible_start,
      least(month_end_exclusive - 1, v_today) as eligible_end
    from month_calendar
  ), monthly_completion as (
    select
      month_number,
      month_name,
      eligible_start,
      eligible_end,
      case
        when eligible_end >= eligible_start then (eligible_end - eligible_start) + 1
        else 0
      end as eligible_days,
      case
        when eligible_end >= eligible_start then (
          select count(*)::integer
          from unnest(v_completed_dates) completed_date
          where completed_date between month_windows.eligible_start and month_windows.eligible_end
        )
        else 0
      end as completed_days
    from month_windows
  )
  select jsonb_agg(
    jsonb_build_object(
      'month', month_number,
      'monthName', month_name,
      'completedDays', completed_days,
      'eligibleDays', eligible_days,
      'percentage', case
        when eligible_days = 0 then 0
        else round((completed_days::numeric * 100) / eligible_days, 2)
      end
    )
    order by month_number
  )
  into v_months
  from monthly_completion;

  with selected_month_calendar as (
    select calendar_day::date as calendar_date
    from generate_series(
      make_date(v_year, v_selected_month, 1)::timestamp,
      (make_date(v_year, v_selected_month, 1) + interval '1 month - 1 day')::timestamp,
      interval '1 day'
    ) as calendar_days(calendar_day)
  )
  select jsonb_agg(
    jsonb_build_object(
      'day', extract(day from calendar_date)::integer,
      'date', calendar_date,
      'completed', case
        when calendar_date > v_today then null
        else calendar_date = any(v_completed_dates)
      end
    )
    order by calendar_date
  )
  into v_days
  from selected_month_calendar;

  return jsonb_build_object(
    'year', v_year,
    'selectedMonth', v_selected_month,
    'completedDays', v_year_completed_days,
    'eligibleDays', v_year_eligible_days,
    'yearToDatePercentage', v_year_percentage,
    'months', coalesce(v_months, '[]'::jsonb),
    'days', coalesce(v_days, '[]'::jsonb)
  );
end;
$$;

revoke all on function api.get_my_rosary_completion(integer, smallint) from public, anon;
grant execute on function api.get_my_rosary_completion(integer, smallint) to authenticated, service_role;
