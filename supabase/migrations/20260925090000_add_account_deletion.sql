-- Permanently remove account data while retaining only an anonymous Rosary
-- lifetime aggregate for the public global statistic.

create table app.deleted_account_rosary_totals (
  singleton boolean primary key default true check (singleton),
  rosaries_prayed bigint not null default 0 check (rosaries_prayed >= 0)
);

insert into app.deleted_account_rosary_totals (singleton, rosaries_prayed)
values (true, 0)
on conflict (singleton) do nothing;

revoke all on table app.deleted_account_rosary_totals
from public, anon, authenticated;

create or replace function api.delete_current_user_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_rosaries_prayed bigint;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select coalesce(sum(activity.quantity), 0)::bigint
  into v_rosaries_prayed
  from competition.spiritual_activities activity
  where activity.user_id = v_user_id
    and activity.activity_code = 'ROSARY'
    and activity.verification_status in ('self_reported', 'verified');

  update app.deleted_account_rosary_totals
  set rosaries_prayed = rosaries_prayed + v_rosaries_prayed
  where singleton;

  delete from app.users
  where id = v_user_id;
end;
$$;

revoke all on function api.delete_current_user_account() from public, anon;
grant execute on function api.delete_current_user_account() to authenticated, service_role;

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
  v_deleted_account_rosaries bigint;
  v_percentage numeric;
begin
  select coalesce(rosaries_prayed, 0)
  into v_deleted_account_rosaries
  from app.deleted_account_rosary_totals
  where singleton;

  select
    coalesce(sum(activity.quantity), 0)::bigint + coalesce(v_deleted_account_rosaries, 0),
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
