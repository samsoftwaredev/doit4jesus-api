-- Keep the friends leaderboard's paginated entries separate from the
-- authenticated user's entry, so clients can always render the caller's rank.

create or replace function api.get_current_user_friends_leaderboard(
  p_period_type text default 'weekly',
  p_period_code text default null,
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
  v_user_id uuid := auth.uid();
  v_period competition.leaderboard_periods%rowtype;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_period_type not in ('daily', 'weekly', 'monthly', 'yearly', 'season') then
    raise exception 'INVALID_FRIEND_LEADERBOARD_PERIOD_TYPE' using errcode = 'P0001';
  end if;

  if p_period_code is not null then
    select *
    into v_period
    from competition.leaderboard_periods period_record
    where period_record.period_type = p_period_type
      and period_record.code = p_period_code
    limit 1;
  else
    select *
    into v_period
    from competition.leaderboard_periods period_record
    where period_record.period_type = p_period_type
      and period_record.status in ('active', 'finalized')
    order by period_record.starts_at desc
    limit 1;
  end if;

  if not found then
    raise exception 'FRIEND_LEADERBOARD_PERIOD_NOT_FOUND' using errcode = 'P0001';
  end if;

  return (
    with friend_ids as (
      select v_user_id as user_id
      union
      select case
        when friendship.user_low_id = v_user_id then friendship.user_high_id
        else friendship.user_low_id
      end
      from app.friendships friendship
      where v_user_id in (friendship.user_low_id, friendship.user_high_id)
    ), ranked as (
      select
        friend_ids.user_id,
        profile.display_name,
        profile.username,
        profile.avatar_url,
        profile.title,
        coalesce(entry.points, 0) as points,
        coalesce(entry.rosaries_count, 0) as rosaries_count,
        coalesce(entry.scripture_readings_count, 0) as scripture_readings_count,
        coalesce(entry.prayers_count, 0) as prayers_count,
        rank() over (order by coalesce(entry.points, 0) desc) as rank
      from friend_ids
      join app.user_profiles profile on profile.user_id = friend_ids.user_id
      left join competition.leaderboard_entries entry
        on entry.period_id = v_period.id
        and entry.user_id = friend_ids.user_id
        and entry.scope_type = 'global'
        and entry.scope_reference = 'global'
    ), paged as (
      select *
      from ranked
      order by rank, display_name, user_id
      limit greatest(1, least(coalesce(p_limit, 50), 100))
      offset greatest(coalesce(p_offset, 0), 0)
    )
    select jsonb_build_object(
      'period', jsonb_build_object(
        'id', v_period.id,
        'periodType', v_period.period_type,
        'code', v_period.code,
        'name', v_period.name,
        'startsAt', v_period.starts_at,
        'endsAt', v_period.ends_at,
        'status', v_period.status
      ),
      'entries', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'rank', paged.rank,
            'points', paged.points,
            'rosariesCount', paged.rosaries_count,
            'scriptureReadingsCount', paged.scripture_readings_count,
            'prayersCount', paged.prayers_count,
            'isCurrentUser', paged.user_id = v_user_id,
            'friend', jsonb_build_object(
              'id', paged.user_id,
              'displayName', paged.display_name,
              'username', paged.username,
              'avatarUrl', paged.avatar_url,
              'title', paged.title
            )
          ) order by paged.rank, paged.display_name, paged.user_id
        )
        from paged
      ), '[]'::jsonb),
      'currentUserEntry', (
        select jsonb_build_object(
          'rank', current_user_record.rank,
          'points', current_user_record.points,
          'rosariesCount', current_user_record.rosaries_count,
          'scriptureReadingsCount', current_user_record.scripture_readings_count,
          'prayersCount', current_user_record.prayers_count,
          'isCurrentUser', true,
          'friend', jsonb_build_object(
            'id', current_user_record.user_id,
            'displayName', current_user_record.display_name,
            'username', current_user_record.username,
            'avatarUrl', current_user_record.avatar_url,
            'title', current_user_record.title
          )
        )
        from ranked current_user_record
        where current_user_record.user_id = v_user_id
      ),
      'total', (select count(*) from ranked)
    )
  );
end;
$$;
