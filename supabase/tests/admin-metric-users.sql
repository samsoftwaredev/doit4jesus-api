-- Run against the local seeded database. Every data change is rolled back.
begin;

do $$
declare
  v_admin_id uuid := '33333333-3333-4333-8333-333333333333';
  v_non_admin_id uuid;
  v_metrics jsonb;
  v_list jsonb;
  v_failed boolean;
begin
  select account.id into v_non_admin_id
  from app.users account
  where not exists (
    select 1 from app.user_roles role_record
    where role_record.user_id = account.id and role_record.role = 'admin'
  )
  limit 1;

  -- Non-administrators are rejected.
  if v_non_admin_id is not null then
    perform set_config('request.jwt.claim.sub', v_non_admin_id::text, true);
    v_failed := false;
    begin
      perform api.get_admin_metric_users('total_users');
    exception when others then
      v_failed := sqlerrm = 'FORBIDDEN';
    end;
    if not v_failed then raise exception 'Expected a non-administrator to be rejected'; end if;
  end if;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);

  -- Unknown metrics are rejected.
  v_failed := false;
  begin
    perform api.get_admin_metric_users('nope');
  exception when others then
    v_failed := sqlerrm = 'INVALID_ADMIN_METRIC';
  end;
  if not v_failed then raise exception 'Expected an unknown metric to be rejected'; end if;

  -- Each list is the same population as its card.
  v_metrics := api.get_admin_app_metrics();

  v_list := api.get_admin_metric_users('total_users', 'all', 1, 0);
  if (v_list ->> 'total')::bigint <> (v_metrics ->> 'totalUsers')::bigint then
    raise exception 'total_users list % differs from card %', v_list ->> 'total', v_metrics ->> 'totalUsers';
  end if;

  v_list := api.get_admin_metric_users('dau', 'all', 1, 0);
  if (v_list ->> 'total')::bigint <> (v_metrics ->> 'dailyActiveUsers')::bigint then
    raise exception 'dau list differs from card';
  end if;

  v_list := api.get_admin_metric_users('wau', 'all', 1, 0);
  if (v_list ->> 'total')::bigint <> (v_metrics ->> 'weeklyActiveUsers')::bigint then
    raise exception 'wau list differs from card';
  end if;

  v_list := api.get_admin_metric_users('signups_30d', 'all', 1, 0);
  if (v_list ->> 'total')::bigint <> (v_metrics ->> 'signups30d')::bigint then
    raise exception 'signups_30d list differs from card';
  end if;

  -- yes + no partition the counted users.
  v_list := api.get_admin_metric_users('signup_to_active', 'all', 1, 0);
  if (v_list ->> 'positiveTotal')::bigint
     + (api.get_admin_metric_users('signup_to_active', 'no', 1, 0) ->> 'total')::bigint
     <> (v_list ->> 'scopeTotal')::bigint then
    raise exception 'signup_to_active yes/no do not partition the scope';
  end if;

  -- Rows carry the contact details the administrator needs.
  v_list := api.get_admin_metric_users('total_users', 'all', 1, 0);
  if jsonb_array_length(v_list -> 'users') > 0
     and not (v_list -> 'users' -> 0 ? 'email' and v_list -> 'users' -> 0 ? 'displayName') then
    raise exception 'Expected email and displayName on each row';
  end if;
end
$$;

rollback;
