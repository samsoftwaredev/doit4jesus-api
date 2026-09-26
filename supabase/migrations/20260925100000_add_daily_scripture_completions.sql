create table prayer.daily_scripture_completions (
  user_id uuid not null references app.users(id) on delete cascade,
  reading_date date not null,
  activity_id uuid unique references competition.spiritual_activities(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (user_id, reading_date)
);

alter table prayer.daily_scripture_completions enable row level security;
revoke all on table prayer.daily_scripture_completions from public, anon, authenticated;

create or replace function api.get_my_daily_scripture_completion(p_reading_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_completion prayer.daily_scripture_completions%rowtype;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select * into v_completion
  from prayer.daily_scripture_completions
  where user_id = v_user_id and reading_date = p_reading_date;

  return jsonb_build_object(
    'completed', found,
    'completedAt', case when found then v_completion.completed_at else null end
  );
end;
$$;

create or replace function api.complete_daily_scripture(
  p_reading_date date,
  p_idempotency_key varchar
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_completion prayer.daily_scripture_completions%rowtype;
  v_activity_result jsonb;
  v_activity_id uuid;
  v_internal_key varchar;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if p_reading_date is null then
    raise exception 'INVALID_DAILY_SCRIPTURE_DATE' using errcode = 'P0001';
  end if;
  if coalesce(length(trim(p_idempotency_key)), 0) = 0 or length(p_idempotency_key) > 150 then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = 'P0001';
  end if;

  insert into prayer.daily_scripture_completions (user_id, reading_date, activity_id)
  values (v_user_id, p_reading_date, null)
  on conflict (user_id, reading_date) do nothing
  returning * into v_completion;

  if not found then
    select * into v_completion
    from prayer.daily_scripture_completions
    where user_id = v_user_id and reading_date = p_reading_date;
    return jsonb_build_object(
      'replayed', true,
      'completion', jsonb_build_object(
        'readingDate', v_completion.reading_date,
        'completedAt', v_completion.completed_at,
        'activityId', v_completion.activity_id
      )
    );
  end if;

  v_internal_key := 'daily-scripture:' || md5(v_user_id::text || ':' || p_reading_date::text || ':' || p_idempotency_key);
  v_activity_result := api.record_spiritual_activity(
    'SCRIPTURE', now(), now(), null::integer, 1, null::varchar, v_internal_key,
    jsonb_build_object('dailyReadingDate', p_reading_date)
  );
  v_activity_id := (v_activity_result -> 'activity' ->> 'id')::uuid;

  update prayer.daily_scripture_completions
  set activity_id = v_activity_id
  where user_id = v_user_id and reading_date = p_reading_date
  returning * into v_completion;

  return jsonb_build_object(
    'replayed', false,
    'completion', jsonb_build_object(
      'readingDate', v_completion.reading_date,
      'completedAt', v_completion.completed_at,
      'activityId', v_completion.activity_id
    ),
    'activity', v_activity_result -> 'activity',
    'progressUpdates', v_activity_result -> 'progressUpdates',
    'battleUpdates', v_activity_result -> 'battleUpdates',
    'newBadges', v_activity_result -> 'newBadges',
    'xp', v_activity_result -> 'xp'
  );
end;
$$;

revoke all on function api.get_my_daily_scripture_completion(date) from public, anon;
revoke all on function api.complete_daily_scripture(date, varchar) from public, anon;
grant execute on function api.get_my_daily_scripture_completion(date) to authenticated, service_role;
grant execute on function api.complete_daily_scripture(date, varchar) to authenticated, service_role;
