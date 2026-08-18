-- Friend details can opt into a single friend's Rosary streak without loading
-- the full friends list. Friendship authorization remains inside this RPC.

drop function api.get_current_user_friend_details(uuid);

create function api.get_current_user_friend_details(
  p_friend_id uuid,
  p_include_rosary_streak boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if not app.are_users_friends(v_user_id, p_friend_id) then
    raise exception 'FRIENDSHIP_NOT_FOUND' using errcode = 'P0001';
  end if;

  select jsonb_build_object(
    'friend', jsonb_build_object(
      'id', profile.user_id,
      'displayName', profile.display_name,
      'username', profile.username,
      'avatarUrl', profile.avatar_url,
      'title', profile.title
    ),
    'progress', jsonb_build_object(
      'totalXp', coalesce(progress.total_xp, 0),
      'currentLevel', jsonb_build_object(
        'levelNumber', coalesce(progress.current_level, 1),
        'code', level.code,
        'name', level.name,
        'description', level.description,
        'minimumTotalXp', level.minimum_total_xp,
        'iconUrl', level.icon_url,
        'imageUrl', level.image_url
      )
    ),
    'rosaryTotal', coalesce((
      select sum(activity.quantity)::bigint
      from competition.spiritual_activities activity
      where activity.user_id = p_friend_id
        and activity.activity_code = 'ROSARY'
        and activity.verification_status in ('self_reported', 'verified')
    ), 0),
    'badges', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', user_badge.id,
          'earnedAt', user_badge.earned_at,
          'sequenceNumber', user_badge.sequence_number,
          'isFeatured', user_badge.is_featured,
          'badge', jsonb_build_object(
            'id', badge.id,
            'code', badge.code,
            'name', badge.name,
            'description', badge.description,
            'category', badge.category,
            'rarity', badge.rarity,
            'iconUrl', badge.icon_url,
            'lockedIconUrl', badge.locked_icon_url,
            'isRepeatable', badge.is_repeatable,
            'isShareable', badge.is_shareable
          )
        ) order by user_badge.earned_at desc, user_badge.id desc
      )
      from competition.user_badges user_badge
      join competition.badge_definitions badge on badge.id = user_badge.badge_id
      where user_badge.user_id = p_friend_id
    ), '[]'::jsonb)
  ) || case
    when p_include_rosary_streak then jsonb_build_object(
      'rosaryStreak', app.calculate_user_rosary_streak(p_friend_id, profile.timezone)
    )
    else '{}'::jsonb
  end
  into v_result
  from app.user_profiles profile
  left join competition.user_progress progress on progress.user_id = profile.user_id
  left join competition.level_definitions level on level.level_number = progress.current_level
  where profile.user_id = p_friend_id;

  if v_result is null then
    raise exception 'FRIENDSHIP_NOT_FOUND' using errcode = 'P0001';
  end if;

  return v_result;
end;
$$;

revoke all on function api.get_current_user_friend_details(uuid, boolean)
  from public, anon;
grant execute on function api.get_current_user_friend_details(uuid, boolean)
  to authenticated, service_role;
