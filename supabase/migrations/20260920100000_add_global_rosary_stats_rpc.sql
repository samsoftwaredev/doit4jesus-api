-- Return the lifetime Rosary total across all users and, when authenticated,
-- the current user's contribution to that total.

create or replace function api.get_global_rosary_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_total_rosaries bigint;
  v_user_rosaries bigint;
  v_percentage numeric;
begin
  select
    coalesce(sum(activity.quantity), 0)::bigint,
    coalesce(
      sum(activity.quantity) filter (where activity.user_id = v_user_id),
      0
    )::bigint
  into v_total_rosaries, v_user_rosaries
  from competition.spiritual_activities activity
  where activity.activity_code = 'ROSARY'
    and activity.verification_status in ('self_reported', 'verified');

  if v_user_id is null then
    return jsonb_build_object(
      'totalRosariesPrayed', v_total_rosaries,
      'currentUserContribution', null
    );
  end if;

  v_percentage := case
    when v_total_rosaries = 0 then 0::numeric
    else round((v_user_rosaries::numeric * 100) / v_total_rosaries, 4)
  end;

  return jsonb_build_object(
    'totalRosariesPrayed', v_total_rosaries,
    'currentUserContribution', jsonb_build_object(
      'rosariesPrayed', v_user_rosaries,
      'percentage', v_percentage
    )
  );
end;
$$;

revoke all on function api.get_global_rosary_stats() from public;
grant execute on function api.get_global_rosary_stats() to anon, authenticated, service_role;
