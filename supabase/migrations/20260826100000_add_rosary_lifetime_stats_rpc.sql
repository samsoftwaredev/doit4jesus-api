-- Return the current user's all-time Rosary total. Keep its qualifying
-- activity rules consistent with rosary totals shown in friend responses.

create or replace function api.get_my_rosary_stats()
returns jsonb
language plpgsql
stable
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

  return jsonb_build_object('rosariesPrayed', v_rosaries_prayed);
end;
$$;

revoke all on function api.get_my_rosary_stats() from public, anon;
grant execute on function api.get_my_rosary_stats() to authenticated, service_role;
