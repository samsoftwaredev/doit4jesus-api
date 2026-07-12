


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."event_occurrance" AS ENUM (
    'weekly',
    'daily',
    'bi_weekly',
    'monthly',
    'quarterly',
    'annually',
    'on_demand'
);


ALTER TYPE "public"."event_occurrance" OWNER TO "postgres";


CREATE TYPE "public"."event_target_age" AS ENUM (
    'all',
    'children',
    'adolescents',
    'adults',
    'seniors',
    'custom',
    'young_adults'
);


ALTER TYPE "public"."event_target_age" OWNER TO "postgres";


COMMENT ON TYPE "public"."event_target_age" IS 'The type ages allowed';



CREATE TYPE "public"."event_target_group" AS ENUM (
    'married',
    'single',
    'cohabiting',
    'separated',
    'widowed',
    'all'
);


ALTER TYPE "public"."event_target_group" OWNER TO "postgres";


CREATE TYPE "public"."event_type" AS ENUM (
    'youtube_video',
    'cultural_arts',
    'educational',
    'social_community',
    'sports_recreation',
    'political_civic',
    'business_networking',
    'holiday_seasonal',
    'health_wellness',
    'miscellaneous',
    'online'
);


ALTER TYPE "public"."event_type" OWNER TO "postgres";


CREATE TYPE "public"."gender" AS ENUM (
    'male',
    'female'
);


ALTER TYPE "public"."gender" OWNER TO "postgres";


CREATE TYPE "public"."language" AS ENUM (
    'en',
    'es'
);


ALTER TYPE "public"."language" OWNER TO "postgres";


COMMENT ON TYPE "public"."language" IS 'languages that the app supports';



CREATE TYPE "public"."sin_type" AS ENUM (
    'mortal',
    'venial',
    'both'
);


ALTER TYPE "public"."sin_type" OWNER TO "postgres";


COMMENT ON TYPE "public"."sin_type" IS 'The types of sins a human can commit';



CREATE OR REPLACE FUNCTION "public"."admin_retention_d1"() RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  WITH eligible AS (
    SELECT id
    FROM profiles
    WHERE created_at <= NOW() - INTERVAL '1 day'
  ),
  retained AS (
    SELECT DISTINCT e.user_id
    FROM xp_events e
    JOIN eligible u ON u.id = e.user_id
    WHERE e.created_at <= (
      SELECT p.created_at + INTERVAL '1 day'
      FROM profiles p WHERE p.id = e.user_id
    )
    AND e.created_at > (SELECT p.created_at FROM profiles p WHERE p.id = e.user_id)
  )
  SELECT CASE WHEN (SELECT COUNT(*) FROM eligible) = 0 THEN 0
    ELSE ROUND((SELECT COUNT(*) FROM retained)::NUMERIC / (SELECT COUNT(*) FROM eligible) * 100, 1)
  END;
$$;


ALTER FUNCTION "public"."admin_retention_d1"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_retention_d30"() RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  WITH eligible AS (
    SELECT id
    FROM profiles
    WHERE created_at <= NOW() - INTERVAL '30 days'
  ),
  retained AS (
    SELECT DISTINCT e.user_id
    FROM xp_events e
    JOIN eligible u ON u.id = e.user_id
    WHERE e.created_at <= (
      SELECT p.created_at + INTERVAL '30 days'
      FROM profiles p WHERE p.id = e.user_id
    )
    AND e.created_at > (SELECT p.created_at FROM profiles p WHERE p.id = e.user_id)
  )
  SELECT CASE WHEN (SELECT COUNT(*) FROM eligible) = 0 THEN 0
    ELSE ROUND((SELECT COUNT(*) FROM retained)::NUMERIC / (SELECT COUNT(*) FROM eligible) * 100, 1)
  END;
$$;


ALTER FUNCTION "public"."admin_retention_d30"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_retention_d7"() RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  WITH eligible AS (
    SELECT id
    FROM profiles
    WHERE created_at <= NOW() - INTERVAL '7 days'
  ),
  retained AS (
    SELECT DISTINCT e.user_id
    FROM xp_events e
    JOIN eligible u ON u.id = e.user_id
    WHERE e.created_at <= (
      SELECT p.created_at + INTERVAL '7 days'
      FROM profiles p WHERE p.id = e.user_id
    )
    AND e.created_at > (SELECT p.created_at FROM profiles p WHERE p.id = e.user_id)
  )
  SELECT CASE WHEN (SELECT COUNT(*) FROM eligible) = 0 THEN 0
    ELSE ROUND((SELECT COUNT(*) FROM retained)::NUMERIC / (SELECT COUNT(*) FROM eligible) * 100, 1)
  END;
$$;


ALTER FUNCTION "public"."admin_retention_d7"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."award_xp"("p_user_id" "uuid", "p_action_type" "text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_rule public.xp_rules%rowtype;
  v_user_xp public.user_xp%rowtype;
  v_level_row record;
  v_prev_level integer;
  v_bonus integer := 0;
  v_awarded_xp integer := 0;
  v_duplicate boolean := false;
  v_streak_value text;
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  -- Require ownership when called from a signed-in session.
  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'Not allowed to award XP for another user';
  end if;

  perform public.ensure_user_xp_row(p_user_id);

  select *
    into v_user_xp
  from public.user_xp
  where user_id = p_user_id
  for update;

  v_prev_level := v_user_xp.current_level;

  if p_idempotency_key is not null then
    if exists (
      select 1
      from public.xp_events
      where user_id = p_user_id
        and idempotency_key = p_idempotency_key
    ) then
      v_duplicate := true;
    end if;
  end if;

  if not v_duplicate then
    select *
      into v_rule
    from public.xp_rules
    where action_type = p_action_type
      and is_active = true;

    if not found then
      raise exception 'No active XP rule for action_type=%', p_action_type;
    end if;

    if p_action_type = 'streak' and p_metadata ? 'streak_length' then
      v_streak_value := p_metadata->>'streak_length';
      v_bonus := coalesce(
        (v_rule.optional_conditions->'milestone_bonus'->>v_streak_value)::integer,
        0
      );
    end if;

    v_awarded_xp := v_rule.xp_value + greatest(v_bonus, 0);

    insert into public.xp_events (
      user_id,
      type,
      xp_amount,
      metadata,
      idempotency_key
    )
    values (
      p_user_id,
      p_action_type,
      v_awarded_xp,
      coalesce(p_metadata, '{}'::jsonb),
      p_idempotency_key
    );

    update public.user_xp
      set total_xp = total_xp + v_awarded_xp
    where user_id = p_user_id
    returning * into v_user_xp;
  end if;

  select *
    into v_level_row
  from public.calculate_xp_level(v_user_xp.total_xp)
  limit 1;

  update public.user_xp
    set current_level = v_level_row.level,
        current_title = v_level_row.title
  where user_id = p_user_id
  returning * into v_user_xp;

  if not v_duplicate and v_level_row.level > v_prev_level then
    insert into public.xp_events (
      user_id,
      type,
      xp_amount,
      metadata,
      idempotency_key
    )
    values (
      p_user_id,
      'level_up',
      0,
      jsonb_build_object(
        'previous_level', v_prev_level,
        'new_level', v_level_row.level,
        'new_title', v_level_row.title
      ),
      concat('level_up:', p_action_type, ':', v_level_row.level, ':', coalesce(p_idempotency_key, 'auto'))
    )
    on conflict (user_id, idempotency_key) where idempotency_key is not null do nothing;
  end if;

  return jsonb_build_object(
    'duplicate', v_duplicate,
    'awarded_xp', case when v_duplicate then 0 else v_awarded_xp end,
    'total_xp', v_user_xp.total_xp,
    'previous_level', v_prev_level,
    'current_level', v_user_xp.current_level,
    'current_title', v_user_xp.current_title,
    'leveled_up', (v_user_xp.current_level > v_prev_level) and not v_duplicate,
    'next_level', v_level_row.next_level,
    'next_title', v_level_row.next_title,
    'next_min_xp', v_level_row.next_min_xp
  );
end;
$$;


ALTER FUNCTION "public"."award_xp"("p_user_id" "uuid", "p_action_type" "text", "p_metadata" "jsonb", "p_idempotency_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."becoming_friends"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF (NEW.uuid1_accepted AND NEW.uuid2_accepted) THEN
        INSERT INTO friends (uuid1, uuid2)
        VALUES (NEW.uuid1, NEW.uuid2);

        DELETE FROM friend_requests
        WHERE uuid1 = NEW.uuid1 AND uuid2 = NEW.uuid2;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."becoming_friends"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_xp_level"("p_total_xp" integer) RETURNS TABLE("level" integer, "title" "text", "min_xp" integer, "next_level" integer, "next_title" "text", "next_min_xp" integer)
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  with current_level as (
    select c.level, c.title, c.min_xp
    from public.xp_levels_config c
    where c.min_xp <= greatest(p_total_xp, 0)
    order by c.min_xp desc
    limit 1
  ),
  upcoming as (
    select n.level, n.title, n.min_xp
    from public.xp_levels_config n
    where n.min_xp > greatest(p_total_xp, 0)
    order by n.min_xp asc
    limit 1
  )
  select
    c.level,
    c.title,
    c.min_xp,
    u.level as next_level,
    u.title as next_title,
    u.min_xp as next_min_xp
  from current_level c
  left join upcoming u on true;
$$;


ALTER FUNCTION "public"."calculate_xp_level"("p_total_xp" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_user_xp_row"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_default_level integer;
  v_default_title text;
begin
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;

  select level, title
    into v_default_level, v_default_title
  from public.xp_levels_config
  order by min_xp asc
  limit 1;

  if v_default_level is null then
    v_default_level := 1;
    v_default_title := 'Orange';
  end if;

  insert into public.user_xp (user_id, total_xp, current_level, current_title)
  values (p_user_id, 0, v_default_level, v_default_title)
  on conflict (user_id) do nothing;
end;
$$;


ALTER FUNCTION "public"."ensure_user_xp_row"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."expire_stale_prayer_sessions"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.global_prayer_sessions
  SET is_active = false, updated_at = now()
  WHERE is_active = true
    AND updated_at < now() - interval '2 hours';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."expire_stale_prayer_sessions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_all_rosary_count"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$BEGIN
    RETURN (
        SELECT COUNT(*) FROM rosary_stats
    );
END;$$;


ALTER FUNCTION "public"."get_all_rosary_count"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."prayer_locations" (
    "id" integer NOT NULL,
    "city" "text" NOT NULL,
    "country_code" "text" NOT NULL,
    "country_name" "text" NOT NULL,
    "latitude" numeric NOT NULL,
    "longitude" numeric NOT NULL,
    "prayer_count" integer DEFAULT 0 NOT NULL,
    "live_sessions" integer DEFAULT 0 NOT NULL,
    "active_users" integer DEFAULT 0 NOT NULL,
    "last_updated" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."prayer_locations" OWNER TO "postgres";


COMMENT ON TABLE "public"."prayer_locations" IS 'City-level prayer activity aggregated from rosary completions and sessions.';



CREATE OR REPLACE FUNCTION "public"."get_prayer_map_cities"() RETURNS SETOF "public"."prayer_locations"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    AS $$
  SELECT * FROM public.prayer_locations
  ORDER BY prayer_count DESC;
$$;


ALTER FUNCTION "public"."get_prayer_map_cities"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_profiles_by_user_ids"("user_ids" "uuid"[]) RETURNS TABLE("first_name" "text", "last_name" "text", "picture_url" "text", "rosary_count" bigint, "id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT profiles.first_name, profiles.last_name, profiles.picture_url, profiles.rosary_count, profiles.id
  FROM profiles
  WHERE profiles.id = ANY(user_ids::UUID[])
  LIMIT 100;
END;
$$;


ALTER FUNCTION "public"."get_profiles_by_user_ids"("user_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_top_10_user_ids"() RETURNS TABLE("user_id" "uuid", "user_count" bigint)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT rosary_stats.user_id, COUNT(*) AS user_count
    FROM rosary_stats
    GROUP BY rosary_stats.user_id
    ORDER BY user_count DESC
    LIMIT 10;
END;
$$;


ALTER FUNCTION "public"."get_top_10_user_ids"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_top_10_user_profile"() RETURNS TABLE("user_id" "uuid", "user_count" bigint, "first_name" "text", "last_name" "text", "picture_url" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT rs.user_id, COUNT(*) AS user_count, pr.first_name, pr.last_name, pr.picture_url
    FROM rosary_stats rs
    JOIN profiles pr ON rs.user_id = pr.id
    GROUP BY rs.user_id, pr.first_name, pr.last_name, pr.picture_url
    ORDER BY user_count DESC
    LIMIT 10;
END;
$$;


ALTER FUNCTION "public"."get_top_10_user_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_achievement_dashboard"("target_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  stats_record record;
  summary jsonb;
  earned_badges jsonb;
  badge_definitions jsonb;
  progress_items jsonb;
begin
  if target_user_id is null then
    raise exception 'target_user_id is required';
  end if;

  if auth.uid() is not null and auth.uid() <> target_user_id then
    raise exception 'not allowed';
  end if;

  select
    coalesce(p.rosary_streak, 0) as prayer_streak,
    coalesce((select count(*) from public.rosary_stats rs where rs.user_id = target_user_id), 0) as prayer_count,
    coalesce((select count(*) from public.rosary_stats rs where rs.user_id = target_user_id), 0) as rosary_count,
    coalesce((select count(*) from public.event_messages em where em.user_id = target_user_id and em.deleted_at is null), 0) as community_posts,
    coalesce((select count(*) from public.profiles invited where invited.invited_by = target_user_id), 0) as friends_invited,
    coalesce((select count(*) from public.rosary_stats rs where rs.user_id = target_user_id and rs.join_rosary_user_id is not null), 0) as global_prayer_sessions,
    greatest(floor(coalesce((select count(*) from public.rosary_stats rs where rs.user_id = target_user_id), 0) / 3.0), 0) as scripture_sessions
  into stats_record
  from public.profiles p
  where p.id = target_user_id;

  if stats_record is null then
    raise exception 'profile not found';
  end if;

  insert into public.user_badges (user_id, badge_key)
  select target_user_id, bd.badge_key
  from public.badge_definitions bd
  where case
    when bd.requirement_type = 'prayer_count' then stats_record.prayer_count >= bd.requirement_value
    when bd.requirement_type = 'prayer_streak' then stats_record.prayer_streak >= bd.requirement_value
    when bd.requirement_type = 'rosary_count' then stats_record.rosary_count >= bd.requirement_value
    when bd.requirement_type = 'community_posts' then stats_record.community_posts >= bd.requirement_value
    when bd.requirement_type = 'scripture_sessions' then stats_record.scripture_sessions >= bd.requirement_value
    when bd.requirement_type = 'friends_invited' then stats_record.friends_invited >= bd.requirement_value
    when bd.requirement_type = 'global_prayer_sessions' then stats_record.global_prayer_sessions >= bd.requirement_value
    else false
  end
  on conflict (user_id, badge_key) do nothing;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ub.id,
        'badge_key', ub.badge_key,
        'earned_at', ub.earned_at
      )
      order by ub.earned_at desc
    ),
    '[]'::jsonb
  )
  into earned_badges
  from public.user_badges ub
  where ub.user_id = target_user_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bd.id,
        'badge_key', bd.badge_key,
        'name', bd.name,
        'description', bd.description,
        'category', bd.category,
        'icon_name', bd.icon_name,
        'requirement_type', bd.requirement_type,
        'requirement_value', bd.requirement_value,
        'requirement_label', bd.requirement_label,
        'verse_reference', bd.verse_reference,
        'verse_text', bd.verse_text,
        'share_message', bd.share_message,
        'display_order', bd.display_order
      )
      order by bd.display_order asc
    ),
    '[]'::jsonb
  )
  into badge_definitions
  from public.badge_definitions bd;

  with computed_progress as (
    select
      bd.badge_key,
      bd.name as title,
      bd.requirement_value as target,
      case
        when bd.requirement_type = 'prayer_count' then stats_record.prayer_count
        when bd.requirement_type = 'prayer_streak' then stats_record.prayer_streak
        when bd.requirement_type = 'rosary_count' then stats_record.rosary_count
        when bd.requirement_type = 'community_posts' then stats_record.community_posts
        when bd.requirement_type = 'scripture_sessions' then stats_record.scripture_sessions
        when bd.requirement_type = 'friends_invited' then stats_record.friends_invited
        when bd.requirement_type = 'global_prayer_sessions' then stats_record.global_prayer_sessions
        else 0
      end as current
    from public.badge_definitions bd
    left join public.user_badges ub
      on ub.badge_key = bd.badge_key
      and ub.user_id = target_user_id
    where ub.id is null
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'badge_key', badge_key,
        'title', title,
        'current', least(current, target),
        'target', target,
        'progress_percent', least(100, round((current::numeric / target::numeric) * 100)),
        'encouragement',
          case
            when target - current <= 1 then 'One more faithful step unlocks this badge.'
            else (target - current)::text || ' more steps to reach this milestone.'
          end
      )
      order by round((current::numeric / target::numeric) * 100) desc, target asc
    ),
    '[]'::jsonb
  )
  into progress_items
  from (
    select * from computed_progress
    order by round((current::numeric / target::numeric) * 100) desc, target asc
    limit 3
  ) ranked_progress;

  with next_badge as (
    select
      bd.name,
      greatest(
        bd.requirement_value - case
          when bd.requirement_type = 'prayer_count' then stats_record.prayer_count
          when bd.requirement_type = 'prayer_streak' then stats_record.prayer_streak
          when bd.requirement_type = 'rosary_count' then stats_record.rosary_count
          when bd.requirement_type = 'community_posts' then stats_record.community_posts
          when bd.requirement_type = 'scripture_sessions' then stats_record.scripture_sessions
          when bd.requirement_type = 'friends_invited' then stats_record.friends_invited
          when bd.requirement_type = 'global_prayer_sessions' then stats_record.global_prayer_sessions
          else 0
        end,
        0
      ) as remaining_count,
      round(
        (
          case
            when bd.requirement_type = 'prayer_count' then stats_record.prayer_count
            when bd.requirement_type = 'prayer_streak' then stats_record.prayer_streak
            when bd.requirement_type = 'rosary_count' then stats_record.rosary_count
            when bd.requirement_type = 'community_posts' then stats_record.community_posts
            when bd.requirement_type = 'scripture_sessions' then stats_record.scripture_sessions
            when bd.requirement_type = 'friends_invited' then stats_record.friends_invited
            when bd.requirement_type = 'global_prayer_sessions' then stats_record.global_prayer_sessions
            else 0
          end::numeric / bd.requirement_value::numeric
        ) * 100
      ) as progress_percent
    from public.badge_definitions bd
    left join public.user_badges ub
      on ub.badge_key = bd.badge_key
      and ub.user_id = target_user_id
    where ub.id is null
    order by progress_percent desc nulls last, bd.display_order asc
    limit 1
  )
  select jsonb_build_object(
    'total_badges_earned',
    (select count(*) from public.user_badges ub where ub.user_id = target_user_id),
    'current_prayer_streak',
    stats_record.prayer_streak,
    'next_milestone_name',
    coalesce((select name from next_badge), 'All badges earned'),
    'next_milestone_count',
    coalesce((select remaining_count from next_badge), 0),
    'latest_badge_key',
    (select ub.badge_key from public.user_badges ub where ub.user_id = target_user_id order by ub.earned_at desc limit 1)
  )
  into summary;

  return jsonb_build_object(
    'stats',
    jsonb_build_object(
      'prayer_count', stats_record.prayer_count,
      'prayer_streak', stats_record.prayer_streak,
      'rosary_count', stats_record.rosary_count,
      'community_posts', stats_record.community_posts,
      'scripture_sessions', stats_record.scripture_sessions,
      'friends_invited', stats_record.friends_invited,
      'global_prayer_sessions', stats_record.global_prayer_sessions
    ),
    'summary', summary,
    'earned_badges', earned_badges,
    'badge_definitions', badge_definitions,
    'progress', progress_items
  );
end;
$$;


ALTER FUNCTION "public"."get_user_achievement_dashboard"("target_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date", "p_limit" integer DEFAULT 50) RETURNS TABLE("user_id" "uuid", "first_name" "text", "last_name" "text", "picture_url" "text", "total_xp" integer, "rosaries_count" integer, "streak_days" integer, "invites_count" integer, "rank" integer)
    LANGUAGE "sql" STABLE
    AS $$
  WITH weekly_xp AS (
    SELECT
      e.user_id,
      COALESCE(SUM(e.xp_amount), 0)::INT                                       AS total_xp,
      COALESCE(COUNT(*) FILTER (WHERE e.type = 'rosary_completed'), 0)::INT     AS rosaries_count,
      COALESCE(MAX(CASE WHEN e.type = 'streak' THEN e.xp_amount END), 0)::INT  AS streak_days,
      COALESCE(COUNT(*) FILTER (WHERE e.type = 'friend_invite'), 0)::INT        AS invites_count
    FROM xp_events e
    WHERE e.created_at >= p_week_start
      AND e.created_at <  p_week_end + INTERVAL '1 day'
    GROUP BY e.user_id
  ),
  ranked AS (
    SELECT
      w.*,
      RANK() OVER (
        ORDER BY w.total_xp DESC, w.rosaries_count DESC, w.streak_days DESC
      )::INT AS rank
    FROM weekly_xp w
  )
  SELECT
    r.user_id,
    p.first_name,
    p.last_name,
    p.picture_url,
    r.total_xp,
    r.rosaries_count,
    r.streak_days,
    r.invites_count,
    r.rank
  FROM ranked r
  JOIN profiles p ON p.id = r.user_id
  ORDER BY r.rank ASC
  LIMIT p_limit;
$$;


ALTER FUNCTION "public"."get_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_weekly_leaderboard_me"("p_user_id" "uuid", "p_week_start" "date", "p_week_end" "date", "p_neighbors" integer DEFAULT 3) RETURNS TABLE("user_id" "uuid", "first_name" "text", "last_name" "text", "picture_url" "text", "total_xp" integer, "rosaries_count" integer, "streak_days" integer, "invites_count" integer, "rank" integer, "is_current_user" boolean)
    LANGUAGE "sql" STABLE
    AS $$
  WITH weekly_xp AS (
    SELECT
      e.user_id,
      COALESCE(SUM(e.xp_amount), 0)::INT                                       AS total_xp,
      COALESCE(COUNT(*) FILTER (WHERE e.type = 'rosary_completed'), 0)::INT     AS rosaries_count,
      COALESCE(MAX(CASE WHEN e.type = 'streak' THEN e.xp_amount END), 0)::INT  AS streak_days,
      COALESCE(COUNT(*) FILTER (WHERE e.type = 'friend_invite'), 0)::INT        AS invites_count
    FROM xp_events e
    WHERE e.created_at >= p_week_start
      AND e.created_at <  p_week_end + INTERVAL '1 day'
    GROUP BY e.user_id
  ),
  ranked AS (
    SELECT
      w.*,
      RANK() OVER (
        ORDER BY w.total_xp DESC, w.rosaries_count DESC, w.streak_days DESC
      )::INT AS rank
    FROM weekly_xp w
  ),
  user_rank AS (
    SELECT rank FROM ranked WHERE user_id = p_user_id
  )
  SELECT
    r.user_id,
    p.first_name,
    p.last_name,
    p.picture_url,
    r.total_xp,
    r.rosaries_count,
    r.streak_days,
    r.invites_count,
    r.rank,
    (r.user_id = p_user_id) AS is_current_user
  FROM ranked r
  JOIN profiles p ON p.id = r.user_id
  CROSS JOIN user_rank ur
  WHERE r.rank BETWEEN (ur.rank - p_neighbors) AND (ur.rank + p_neighbors)
  ORDER BY r.rank ASC;
$$;


ALTER FUNCTION "public"."get_weekly_leaderboard_me"("p_user_id" "uuid", "p_week_start" "date", "p_week_end" "date", "p_neighbors" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."global_prayer_sessions_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."global_prayer_sessions_set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$begin
  insert into public.profiles (id, first_name, last_name, gender, username)
  values (
    new.id, 
    new.raw_user_meta_data->>'first_name', 
    new.raw_user_meta_data->>'last_name', 
    new.raw_user_meta_data->>'gender',
    new.raw_user_meta_data->>'username'
  );
  return new;
end;$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_prayer_count"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" numeric, "p_longitude" numeric, "p_increment" integer DEFAULT 1) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.prayer_locations (city, country_code, country_name, latitude, longitude, prayer_count, last_updated)
  VALUES (p_city, p_country_code, p_country_name, p_latitude, p_longitude, p_increment, now())
  ON CONFLICT (city, country_code)
  DO UPDATE SET
    prayer_count = prayer_locations.prayer_count + p_increment,
    last_updated = now(),
    -- Update coords if they changed (shouldn't happen often)
    latitude     = EXCLUDED.latitude,
    longitude    = EXCLUDED.longitude,
    country_name = EXCLUDED.country_name;
END;
$$;


ALTER FUNCTION "public"."increment_prayer_count"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" numeric, "p_longitude" numeric, "p_increment" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."insert_into_rosary_stats"("p_user_id" "uuid", "p_join_rosary_user_id" "uuid", "p_completed_at" "date") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if a row with the same user_id, join_rosary_user_id (or NULL), and completed_at already exists
    IF NOT EXISTS (
        SELECT 1
        FROM rosary_stats
        WHERE (user_id = p_user_id OR (user_id IS NULL AND p_user_id IS NULL))
          AND (join_rosary_user_id = p_join_rosary_user_id OR (join_rosary_user_id IS NULL AND p_join_rosary_user_id IS NULL))
          AND completed_at = p_completed_at
    ) THEN
        -- Insert the new row
        INSERT INTO rosary_stats (user_id, join_rosary_user_id, completed_at)
        VALUES (p_user_id, p_join_rosary_user_id, p_completed_at);
    END IF;

    -- Update rosary_count in the profile table for the user
    UPDATE profiles
    SET rosary_count = (
        SELECT COUNT(*)
        FROM rosary_stats
        WHERE (user_id = p_user_id OR (user_id IS NULL AND p_user_id IS NULL))
    )
    WHERE id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."insert_into_rosary_stats"("p_user_id" "uuid", "p_join_rosary_user_id" "uuid", "p_completed_at" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_global_prayer_session"("p_session_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_new_count integer;
BEGIN
  UPDATE public.global_prayer_sessions
  SET participants_count = participants_count + 1,
      updated_at = now()
  WHERE id = p_session_id AND is_active = true
  RETURNING participants_count INTO v_new_count;

  IF v_new_count IS NULL THEN
    RAISE EXCEPTION 'Session % not found or not active', p_session_id;
  END IF;

  RETURN v_new_count;
END;
$$;


ALTER FUNCTION "public"."join_global_prayer_session"("p_session_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_existing_friend_requests"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN
 IF EXISTS (SELECT 1 FROM friends WHERE (uuid1 = NEW.uuid1 AND uuid2 = NEW.uuid2) OR (uuid1 = NEW.uuid2 AND uuid2 = NEW.uuid1)) THEN DELETE FROM friend_requests WHERE uuid1 = NEW.uuid1 AND uuid2 = NEW.uuid2; END IF; RETURN NEW;
END;$$;


ALTER FUNCTION "public"."remove_existing_friend_requests"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_profiles"("search_text" "text") RETURNS TABLE("id" "uuid", "first_name" "text", "last_name" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF LENGTH(search_text) < 3 THEN
    RETURN QUERY
    SELECT profiles.id, profiles.first_name, profiles.last_name
    FROM profiles
    WHERE FALSE; -- Prevent query execution for less than 3 characters
  ELSE
    RETURN QUERY
    SELECT profiles.id, profiles.first_name, profiles.last_name
    FROM profiles
    WHERE profiles.first_name ILIKE '%' || search_text || '%'
       OR profiles.last_name ILIKE '%' || search_text || '%';
  END IF;
END;
$$;


ALTER FUNCTION "public"."search_profiles"("search_text" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_daily_scripture_cache_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_daily_scripture_cache_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_xp_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_xp_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."snapshot_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO leaderboards_weekly (user_id, week_start, week_end, total_xp, rosaries_count, streak_days, invites_count, rank)
  SELECT user_id, p_week_start, p_week_end, total_xp, rosaries_count, streak_days, invites_count, rank
  FROM get_weekly_leaderboard(p_week_start, p_week_end, 10000)
  ON CONFLICT (user_id, week_start) DO UPDATE SET
    total_xp       = EXCLUDED.total_xp,
    rosaries_count = EXCLUDED.rosaries_count,
    streak_days    = EXCLUDED.streak_days,
    invites_count  = EXCLUDED.invites_count,
    rank           = EXCLUDED.rank;

  INSERT INTO leaderboard_history (user_id, week_start, rank, total_xp, snapshot_data)
  SELECT
    user_id, p_week_start, rank, total_xp,
    jsonb_build_object(
      'rosaries_count', rosaries_count,
      'streak_days', streak_days,
      'invites_count', invites_count
    )
  FROM leaderboards_weekly
  WHERE week_start = p_week_start
  ON CONFLICT (user_id, week_start) DO UPDATE SET
    rank          = EXCLUDED.rank,
    total_xp      = EXCLUDED.total_xp,
    snapshot_data = EXCLUDED.snapshot_data;
END;
$$;


ALTER FUNCTION "public"."snapshot_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_global_prayer_session"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" double precision, "p_longitude" double precision, "p_prayer_type" "text", "p_created_by" "uuid" DEFAULT NULL::"uuid") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_session_id bigint;
begin
  select gps.id
  into v_session_id
  from public.global_prayer_sessions gps
  where gps.is_active = true
    and gps.city = p_city
    and gps.country_code = p_country_code
    and gps.prayer_type = p_prayer_type
    and gps.updated_at >= (now() - interval '4 hours')
  order by gps.updated_at desc
  limit 1;

  if v_session_id is null then
    insert into public.global_prayer_sessions (
      city,
      country_code,
      country_name,
      latitude,
      longitude,
      prayer_type,
      participants_count,
      created_by
    )
    values (
      p_city,
      p_country_code,
      p_country_name,
      p_latitude,
      p_longitude,
      p_prayer_type,
      1,
      coalesce(p_created_by, auth.uid())
    )
    returning id into v_session_id;
  else
    update public.global_prayer_sessions
    set participants_count = participants_count + 1,
        updated_at = now()
    where id = v_session_id;
  end if;

  return v_session_id;
end;
$$;


ALTER FUNCTION "public"."upsert_global_prayer_session"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" double precision, "p_longitude" double precision, "p_prayer_type" "text", "p_created_by" "uuid") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."exam_consciousness" (
    "id" bigint NOT NULL,
    "subject" "text",
    "commandment" bigint,
    "sin_type" "public"."sin_type" DEFAULT 'mortal'::"public"."sin_type",
    "statement" "text",
    "question" "text",
    "for_adults" boolean DEFAULT true,
    "for_teens" boolean DEFAULT false,
    "for_children" boolean DEFAULT false,
    "description" "text" DEFAULT 'false'::"text",
    "for_religious" boolean DEFAULT true,
    "for_matrimonies" boolean DEFAULT false
);


ALTER TABLE "public"."exam_consciousness" OWNER TO "postgres";


COMMENT ON COLUMN "public"."exam_consciousness"."description" IS 'Explain further the question or add resources for the user to keep learning more';



COMMENT ON COLUMN "public"."exam_consciousness"."for_religious" IS 'Hard questions that apply to priests, nuns, etc.';



COMMENT ON COLUMN "public"."exam_consciousness"."for_matrimonies" IS 'This questions only apply to couples with children';



ALTER TABLE "public"."exam_consciousness" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."ConscienceExam_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "description" "text",
    "started_at" timestamp with time zone,
    "attendees" json,
    "picture_url" "text",
    "price" numeric,
    "keywords" "text" DEFAULT ''::"text",
    "slug" "text",
    "updated_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text"),
    "event_type" "public"."event_type",
    "event_source" "uuid",
    "language" "public"."language",
    CONSTRAINT "Events_title_check" CHECK (("length"("title") < 200))
);


ALTER TABLE "public"."events" OWNER TO "postgres";


COMMENT ON TABLE "public"."events" IS 'Actions that the user can subscribe, complete, and share.';



COMMENT ON COLUMN "public"."events"."slug" IS 'The post slug to form the URL.';



ALTER TABLE "public"."events" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."badge_definitions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "badge_key" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" NOT NULL,
    "category" "text" NOT NULL,
    "icon_name" "text" NOT NULL,
    "requirement_type" "text" NOT NULL,
    "requirement_value" integer NOT NULL,
    "requirement_label" "text" NOT NULL,
    "verse_reference" "text" NOT NULL,
    "verse_text" "text" NOT NULL,
    "share_message" "text" NOT NULL,
    "display_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "badge_definitions_requirement_value_check" CHECK (("requirement_value" > 0))
);


ALTER TABLE "public"."badge_definitions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."challenges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "description" "text",
    "deadline" timestamp with time zone,
    "participants" json,
    "completed_by" json,
    "updated_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "goal_amount" bigint,
    "reward" "text",
    "picture_url" "text",
    CONSTRAINT "challenges_goal_amount_check" CHECK (("goal_amount" > 0))
);


ALTER TABLE "public"."challenges" OWNER TO "postgres";


COMMENT ON TABLE "public"."challenges" IS 'gamify the app doing challenges';



COMMENT ON COLUMN "public"."challenges"."goal_amount" IS 'the challenge will be completed once the user reaches this goal amount.';



COMMENT ON COLUMN "public"."challenges"."reward" IS 'what will the user obtain upon completion of challenge';



CREATE TABLE IF NOT EXISTS "public"."churches" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "name" "text" NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "picture_url" "text",
    "description" "text",
    "location" "text",
    "website_url" "text",
    "background_image_url" "text",
    "mass_duration_time" "text",
    "mass_occurrence" "public"."event_occurrance",
    "office_start_time" timestamp with time zone,
    "office_end_time" timestamp with time zone,
    "rating_score" numeric,
    "confession_start_time" timestamp with time zone,
    "confession_end_time" timestamp with time zone,
    "updated_at" timestamp without time zone,
    "eucharistic_adoration_start_time" timestamp with time zone,
    "eucharistic_adoration_end_time" timestamp with time zone,
    "eucharistic_adoration_occurrence" "public"."event_occurrance",
    "confession_occurrence" "public"."event_occurrance"
);


ALTER TABLE "public"."churches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_scripture_cache" (
    "id" bigint NOT NULL,
    "scripture_date" "date" NOT NULL,
    "locale" "text" NOT NULL,
    "liturgical_title" "text" NOT NULL,
    "season" "text" NOT NULL,
    "featured_verse_reference" "text" DEFAULT ''::"text" NOT NULL,
    "featured_verse_text" "text" DEFAULT ''::"text" NOT NULL,
    "readings" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "fetch_status" "text" DEFAULT 'success'::"text" NOT NULL,
    "failed_readings" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "daily_scripture_cache_fetch_status_check" CHECK (("fetch_status" = ANY (ARRAY['success'::"text", 'partial'::"text", 'failed'::"text"]))),
    CONSTRAINT "daily_scripture_cache_locale_check" CHECK (("locale" = ANY (ARRAY['en'::"text", 'es'::"text"])))
);


ALTER TABLE "public"."daily_scripture_cache" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."daily_scripture_cache_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."daily_scripture_cache_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."daily_scripture_cache_id_seq" OWNED BY "public"."daily_scripture_cache"."id";



CREATE TABLE IF NOT EXISTS "public"."daily_scripture_cron_runs" (
    "id" bigint NOT NULL,
    "scripture_date" "date" NOT NULL,
    "locale" "text" NOT NULL,
    "status" "text" NOT NULL,
    "failed_readings" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "daily_scripture_cron_runs_locale_check" CHECK (("locale" = ANY (ARRAY['en'::"text", 'es'::"text"]))),
    CONSTRAINT "daily_scripture_cron_runs_status_check" CHECK (("status" = ANY (ARRAY['success'::"text", 'partial'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."daily_scripture_cron_runs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."daily_scripture_cron_runs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."daily_scripture_cron_runs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."daily_scripture_cron_runs_id_seq" OWNED BY "public"."daily_scripture_cron_runs"."id";



CREATE TABLE IF NOT EXISTS "public"."event_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "message" "text",
    "updated_at" timestamp with time zone,
    "user_id" "uuid" DEFAULT "auth"."uid"(),
    "deleted_at" timestamp with time zone,
    "event_id" bigint,
    "donation_amount" bigint,
    "reply_id" "uuid",
    "first_name" "text",
    "last_name" "text"
);


ALTER TABLE "public"."event_messages" OWNER TO "postgres";


COMMENT ON TABLE "public"."event_messages" IS 'Event Messages';



CREATE TABLE IF NOT EXISTS "public"."event_messages_actions" (
    "id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "likes" json,
    "flagged" "text"
);


ALTER TABLE "public"."event_messages_actions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."friend_requests" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "uuid1" "uuid",
    "uuid2" "uuid",
    "uuid1_accepted" boolean DEFAULT false,
    "uuid2_accepted" boolean DEFAULT false,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."friend_requests" OWNER TO "postgres";


COMMENT ON TABLE "public"."friend_requests" IS 'before becoming friends both parties have to agree';



CREATE TABLE IF NOT EXISTS "public"."friends" (
    "uuid1" "uuid" NOT NULL,
    "is_favorite" boolean DEFAULT false,
    "uuid2" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."friends" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_prayer_sessions" (
    "id" bigint NOT NULL,
    "city" "text" NOT NULL,
    "country_code" "text" NOT NULL,
    "country_name" "text",
    "latitude" double precision NOT NULL,
    "longitude" double precision NOT NULL,
    "prayer_type" "text" NOT NULL,
    "participants_count" integer DEFAULT 1 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid",
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "global_prayer_sessions_participants_count_check" CHECK (("participants_count" >= 0))
);


ALTER TABLE "public"."global_prayer_sessions" OWNER TO "postgres";


COMMENT ON TABLE "public"."global_prayer_sessions" IS 'Live global prayer sessions that users can start and join.';



ALTER TABLE "public"."global_prayer_sessions" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."global_prayer_sessions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."groups" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "group_name" "text" NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"(),
    "picture_url" "text",
    "description" "text",
    "location" "text",
    "audience_age" "public"."event_target_age",
    "target_audience" "public"."event_target_group",
    "website_url" "text",
    "background_image_url" "text",
    "meeting_duration_time" "text",
    "meeting_occurrence" "public"."event_occurrance",
    "meeting_duration_length" numeric,
    "meeting_start_date" "date",
    "meeting_end_date" "date",
    "rating_score" numeric,
    "is_private" boolean DEFAULT false
);


ALTER TABLE "public"."groups" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."latest_event" WITH ("security_invoker"='on') AS
 SELECT DISTINCT ON ("id") "id",
    "started_at"
   FROM "public"."events"
  ORDER BY "id", "started_at" DESC;


ALTER VIEW "public"."latest_event" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."leaderboard_config" (
    "key" "text" NOT NULL,
    "value" "jsonb" NOT NULL
);


ALTER TABLE "public"."leaderboard_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."leaderboard_history" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "week_start" "date" NOT NULL,
    "rank" integer NOT NULL,
    "total_xp" integer DEFAULT 0 NOT NULL,
    "snapshot_data" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."leaderboard_history" OWNER TO "postgres";


ALTER TABLE "public"."leaderboard_history" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."leaderboard_history_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."leaderboards_weekly" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "week_start" "date" NOT NULL,
    "week_end" "date" NOT NULL,
    "total_xp" integer DEFAULT 0 NOT NULL,
    "rosaries_count" integer DEFAULT 0 NOT NULL,
    "streak_days" integer DEFAULT 0 NOT NULL,
    "invites_count" integer DEFAULT 0 NOT NULL,
    "rank" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."leaderboards_weekly" OWNER TO "postgres";


ALTER TABLE "public"."leaderboards_weekly" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."leaderboards_weekly_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."notification_settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "enabled" boolean DEFAULT false,
    "daily_reminder_time" time without time zone DEFAULT '20:00:00'::time without time zone NOT NULL,
    "streak_protection" boolean DEFAULT true,
    "streak_reminder_hours_before" integer DEFAULT 2,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "notification_settings_streak_reminder_hours_before_check" CHECK ((("streak_reminder_hours_before" >= 1) AND ("streak_reminder_hours_before" <= 12)))
);


ALTER TABLE "public"."notification_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "slug" "text" NOT NULL,
    "published_at" timestamp with time zone DEFAULT "now"(),
    "content" json NOT NULL,
    "keywords" "text",
    "author" "text" NOT NULL
);


ALTER TABLE "public"."posts" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."prayer_locations_by_country" AS
 SELECT "country_code",
    "country_name",
    ("sum"("prayer_count"))::integer AS "prayer_count",
    ("sum"("active_users"))::integer AS "active_users",
    ("sum"("live_sessions"))::integer AS "live_sessions",
    "max"("last_updated") AS "last_updated"
   FROM "public"."prayer_locations"
  GROUP BY "country_code", "country_name";


ALTER VIEW "public"."prayer_locations_by_country" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."prayer_locations_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."prayer_locations_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."prayer_locations_id_seq" OWNED BY "public"."prayer_locations"."id";



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone,
    "username" "text",
    "picture_url" "text",
    "gender" "text",
    "birth_date" "date",
    "first_name" "text",
    "last_name" "text",
    "invited_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "rosary_count" bigint DEFAULT '0'::bigint,
    "rosary_streak" numeric DEFAULT '0'::numeric NOT NULL,
    "language" "text",
    "role" "text" DEFAULT 'user'::"text" NOT NULL,
    "city" "text",
    "state" "text",
    "last_seen" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['user'::"text", 'admin'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."invited_by" IS 'The user Id who invited the current user';



COMMENT ON COLUMN "public"."profiles"."rosary_count" IS 'This will store the count of all rosaries. It''s a quick way to reference and compare with other users and get the leader boards.';



COMMENT ON COLUMN "public"."profiles"."rosary_streak" IS 'Highest Rosary Streak';



COMMENT ON COLUMN "public"."profiles"."language" IS 'the language select by the user';



COMMENT ON COLUMN "public"."profiles"."city" IS 'User-provided city for prayer attribution on the global prayer map.';



COMMENT ON COLUMN "public"."profiles"."state" IS 'User-provided state/region (optional, for international users).';



CREATE TABLE IF NOT EXISTS "public"."push_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "subscription" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."push_subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rosary_stats" (
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "completed_at" "date" NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "join_rosary_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."rosary_stats" OWNER TO "postgres";


COMMENT ON COLUMN "public"."rosary_stats"."join_rosary_user_id" IS 'Friend who also prayed the rosary';



CREATE TABLE IF NOT EXISTS "public"."scripture_completions" (
    "id" integer NOT NULL,
    "user_id" "uuid" NOT NULL,
    "liturgical_date" "date" NOT NULL,
    "completed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."scripture_completions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."scripture_completions_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."scripture_completions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."scripture_completions_id_seq" OWNED BY "public"."scripture_completions"."id";



CREATE TABLE IF NOT EXISTS "public"."user_badges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "badge_key" "text" NOT NULL,
    "earned_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "shared_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_badges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_milestones" (
    "user_id" "uuid" NOT NULL,
    "milestone_id" "text" NOT NULL,
    "acknowledged_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_milestones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_xp" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "total_xp" integer DEFAULT 0 NOT NULL,
    "current_level" integer DEFAULT 1 NOT NULL,
    "current_title" "text" DEFAULT 'Orange'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_xp_total_xp_check" CHECK (("total_xp" >= 0))
);


ALTER TABLE "public"."user_xp" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."xp_events" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "xp_amount" integer NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "idempotency_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "xp_events_xp_amount_check" CHECK (("xp_amount" >= 0))
);


ALTER TABLE "public"."xp_events" OWNER TO "postgres";


ALTER TABLE "public"."xp_events" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."xp_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."xp_levels_config" (
    "level" integer NOT NULL,
    "title" "text" NOT NULL,
    "min_xp" integer NOT NULL,
    "badge_key" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "xp_levels_config_min_xp_check" CHECK (("min_xp" >= 0))
);


ALTER TABLE "public"."xp_levels_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."xp_rules" (
    "action_type" "text" NOT NULL,
    "xp_value" integer NOT NULL,
    "optional_conditions" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "description" "text",
    CONSTRAINT "xp_rules_xp_value_check" CHECK (("xp_value" >= 0))
);


ALTER TABLE "public"."xp_rules" OWNER TO "postgres";


COMMENT ON COLUMN "public"."xp_rules"."description" IS 'explain how to achieve this xp';



CREATE TABLE IF NOT EXISTS "public"."youtube" (
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "description" "text",
    "video_id" "text",
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."youtube" OWNER TO "postgres";


ALTER TABLE ONLY "public"."daily_scripture_cache" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."daily_scripture_cache_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."daily_scripture_cron_runs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."daily_scripture_cron_runs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."prayer_locations" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."prayer_locations_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."scripture_completions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."scripture_completions_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."exam_consciousness"
    ADD CONSTRAINT "ConscienceExam_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "Events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "Events_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "Post_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."youtube"
    ADD CONSTRAINT "YouTube_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."youtube"
    ADD CONSTRAINT "YouTube_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."badge_definitions"
    ADD CONSTRAINT "badge_definitions_badge_key_key" UNIQUE ("badge_key");



ALTER TABLE ONLY "public"."badge_definitions"
    ADD CONSTRAINT "badge_definitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."challenges"
    ADD CONSTRAINT "challenges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."churches"
    ADD CONSTRAINT "church_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_scripture_cache"
    ADD CONSTRAINT "daily_scripture_cache_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_scripture_cache"
    ADD CONSTRAINT "daily_scripture_cache_scripture_date_locale_key" UNIQUE ("scripture_date", "locale");



ALTER TABLE ONLY "public"."daily_scripture_cron_runs"
    ADD CONSTRAINT "daily_scripture_cron_runs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_messages_actions"
    ADD CONSTRAINT "event_messages_actions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."friend_requests"
    ADD CONSTRAINT "friend_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "friends_group_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_prayer_sessions"
    ADD CONSTRAINT "global_prayer_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."leaderboard_config"
    ADD CONSTRAINT "leaderboard_config_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."leaderboard_history"
    ADD CONSTRAINT "leaderboard_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."leaderboard_history"
    ADD CONSTRAINT "leaderboard_history_user_id_week_start_key" UNIQUE ("user_id", "week_start");



ALTER TABLE ONLY "public"."leaderboards_weekly"
    ADD CONSTRAINT "leaderboards_weekly_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."leaderboards_weekly"
    ADD CONSTRAINT "leaderboards_weekly_user_id_week_start_key" UNIQUE ("user_id", "week_start");



ALTER TABLE ONLY "public"."event_messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_settings"
    ADD CONSTRAINT "notification_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_settings"
    ADD CONSTRAINT "notification_settings_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."prayer_locations"
    ADD CONSTRAINT "prayer_locations_city_country_code_key" UNIQUE ("city", "country_code");



ALTER TABLE ONLY "public"."prayer_locations"
    ADD CONSTRAINT "prayer_locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."rosary_stats"
    ADD CONSTRAINT "rosary_stats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."scripture_completions"
    ADD CONSTRAINT "scripture_completions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."scripture_completions"
    ADD CONSTRAINT "uq_scripture_user_date" UNIQUE ("user_id", "liturgical_date");



ALTER TABLE ONLY "public"."user_badges"
    ADD CONSTRAINT "user_badges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_badges"
    ADD CONSTRAINT "user_badges_user_id_badge_key_key" UNIQUE ("user_id", "badge_key");



ALTER TABLE ONLY "public"."user_milestones"
    ADD CONSTRAINT "user_milestones_pkey" PRIMARY KEY ("user_id", "milestone_id");



ALTER TABLE ONLY "public"."user_xp"
    ADD CONSTRAINT "user_xp_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_xp"
    ADD CONSTRAINT "user_xp_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."xp_events"
    ADD CONSTRAINT "xp_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."xp_levels_config"
    ADD CONSTRAINT "xp_levels_config_pkey" PRIMARY KEY ("level");



ALTER TABLE ONLY "public"."xp_rules"
    ADD CONSTRAINT "xp_rules_pkey" PRIMARY KEY ("action_type");



CREATE INDEX "global_prayer_sessions_active_idx" ON "public"."global_prayer_sessions" USING "btree" ("is_active", "updated_at" DESC);



CREATE INDEX "global_prayer_sessions_city_prayer_idx" ON "public"."global_prayer_sessions" USING "btree" ("city", "country_code", "prayer_type") WHERE ("is_active" = true);



CREATE INDEX "global_prayer_sessions_location_idx" ON "public"."global_prayer_sessions" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_daily_scripture_cache_date_locale" ON "public"."daily_scripture_cache" USING "btree" ("scripture_date", "locale");



CREATE INDEX "idx_daily_scripture_cache_locale_date" ON "public"."daily_scripture_cache" USING "btree" ("locale", "scripture_date" DESC);



CREATE INDEX "idx_daily_scripture_cron_runs_created_at" ON "public"."daily_scripture_cron_runs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_daily_scripture_cron_runs_date_locale" ON "public"."daily_scripture_cron_runs" USING "btree" ("scripture_date", "locale");



CREATE INDEX "idx_gps_city_country_active" ON "public"."global_prayer_sessions" USING "btree" ("city", "country_code") WHERE ("is_active" = true);



CREATE INDEX "idx_gps_is_active" ON "public"."global_prayer_sessions" USING "btree" ("is_active") WHERE ("is_active" = true);



CREATE INDEX "idx_gps_updated_at" ON "public"."global_prayer_sessions" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_leaderboard_history_user" ON "public"."leaderboard_history" USING "btree" ("user_id", "week_start" DESC);



CREATE INDEX "idx_leaderboards_weekly_user" ON "public"."leaderboards_weekly" USING "btree" ("user_id", "week_start");



CREATE INDEX "idx_leaderboards_weekly_week" ON "public"."leaderboards_weekly" USING "btree" ("week_start", "rank");



CREATE INDEX "idx_notification_settings_enabled" ON "public"."notification_settings" USING "btree" ("enabled") WHERE ("enabled" = true);



CREATE INDEX "idx_notification_settings_user_id" ON "public"."notification_settings" USING "btree" ("user_id");



CREATE INDEX "idx_prayer_locations_country" ON "public"."prayer_locations" USING "btree" ("country_code");



CREATE INDEX "idx_prayer_locations_country_code" ON "public"."prayer_locations" USING "btree" ("country_code");



CREATE INDEX "idx_prayer_locations_last_updated" ON "public"."prayer_locations" USING "btree" ("last_updated" DESC);



CREATE INDEX "idx_prayer_locations_prayer_count" ON "public"."prayer_locations" USING "btree" ("prayer_count" DESC);



CREATE INDEX "idx_profiles_last_seen" ON "public"."profiles" USING "btree" ("last_seen" DESC);



CREATE INDEX "idx_profiles_role" ON "public"."profiles" USING "btree" ("role");



CREATE INDEX "idx_push_subscriptions_user_id" ON "public"."push_subscriptions" USING "btree" ("user_id");



CREATE INDEX "idx_scripture_completions_user" ON "public"."scripture_completions" USING "btree" ("user_id");



CREATE INDEX "idx_xp_events_user_created" ON "public"."xp_events" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "user_badges_badge_key_idx" ON "public"."user_badges" USING "btree" ("badge_key");



CREATE INDEX "user_badges_user_id_idx" ON "public"."user_badges" USING "btree" ("user_id");



CREATE INDEX "user_xp_updated_at_idx" ON "public"."user_xp" USING "btree" ("updated_at" DESC);



CREATE INDEX "user_xp_user_id_idx" ON "public"."user_xp" USING "btree" ("user_id");



CREATE INDEX "xp_events_type_idx" ON "public"."xp_events" USING "btree" ("type");



CREATE INDEX "xp_events_user_id_created_at_idx" ON "public"."xp_events" USING "btree" ("user_id", "created_at" DESC);



CREATE UNIQUE INDEX "xp_events_user_idempotency_unique_idx" ON "public"."xp_events" USING "btree" ("user_id", "idempotency_key") WHERE ("idempotency_key" IS NOT NULL);



CREATE UNIQUE INDEX "xp_levels_config_min_xp_idx" ON "public"."xp_levels_config" USING "btree" ("min_xp");



CREATE OR REPLACE TRIGGER "Invite link user joined app" AFTER INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://uieyknteyflglukepcdy.supabase.co/functions/v1/database-webhook', 'POST', '{"Content-type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpZXlrbnRleWZsZ2x1a2VwY2R5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDQ2NjM2OTYsImV4cCI6MjAyMDIzOTY5Nn0.-EFzqWmh1pyJLPUZ3P9rk_GxBUJmtIUHS-wCXTwBio0"}', '{}', '1000');



CREATE OR REPLACE TRIGGER "friend_request_accepted" AFTER UPDATE ON "public"."friend_requests" FOR EACH ROW EXECUTE FUNCTION "public"."becoming_friends"();



CREATE OR REPLACE TRIGGER "remove_friend_request_if_they_are_friends" AFTER INSERT ON "public"."friend_requests" FOR EACH ROW EXECUTE FUNCTION "public"."remove_existing_friend_requests"();



CREATE OR REPLACE TRIGGER "set_user_xp_updated_at" BEFORE UPDATE ON "public"."user_xp" FOR EACH ROW EXECUTE FUNCTION "public"."set_xp_updated_at"();



CREATE OR REPLACE TRIGGER "set_xp_rules_updated_at" BEFORE UPDATE ON "public"."xp_rules" FOR EACH ROW EXECUTE FUNCTION "public"."set_xp_updated_at"();



CREATE OR REPLACE TRIGGER "trg_daily_scripture_cache_updated_at" BEFORE UPDATE ON "public"."daily_scripture_cache" FOR EACH ROW EXECUTE FUNCTION "public"."set_daily_scripture_cache_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_global_prayer_sessions_updated_at" BEFORE UPDATE ON "public"."global_prayer_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."global_prayer_sessions_set_updated_at"();



ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "Friends_friend_id_fkey" FOREIGN KEY ("uuid1") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "Friends_user_id_fkey" FOREIGN KEY ("uuid2") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_event_source_fkey" FOREIGN KEY ("event_source") REFERENCES "public"."youtube"("id");



ALTER TABLE ONLY "public"."friend_requests"
    ADD CONSTRAINT "friend_requests_friend_id_fkey" FOREIGN KEY ("uuid2") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."friend_requests"
    ADD CONSTRAINT "friend_requests_user_id_fkey" FOREIGN KEY ("uuid1") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."global_prayer_sessions"
    ADD CONSTRAINT "global_prayer_sessions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leaderboard_history"
    ADD CONSTRAINT "leaderboard_history_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leaderboards_weekly"
    ADD CONSTRAINT "leaderboards_weekly_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leaderboards_weekly"
    ADD CONSTRAINT "leaderboards_weekly_user_id_fkey1" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_settings"
    ADD CONSTRAINT "notification_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."event_messages_actions"
    ADD CONSTRAINT "public_event_messages_actions_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."event_messages"("id");



ALTER TABLE ONLY "public"."push_subscriptions"
    ADD CONSTRAINT "push_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rosary_stats"
    ADD CONSTRAINT "rosary_stats_join_rosary_user_id_fkey" FOREIGN KEY ("join_rosary_user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."rosary_stats"
    ADD CONSTRAINT "rosary_stats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."scripture_completions"
    ADD CONSTRAINT "scripture_completions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_badges"
    ADD CONSTRAINT "user_badges_badge_key_fkey" FOREIGN KEY ("badge_key") REFERENCES "public"."badge_definitions"("badge_key") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_badges"
    ADD CONSTRAINT "user_badges_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_milestones"
    ADD CONSTRAINT "user_milestones_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_xp"
    ADD CONSTRAINT "user_xp_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."xp_events"
    ADD CONSTRAINT "xp_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Auth Users Can View Challenge" ON "public"."challenges" FOR SELECT TO "authenticated" USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Badge definitions are viewable by authenticated users" ON "public"."badge_definitions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."event_messages" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."event_messages_actions" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Enable insert for authenticated users only" ON "public"."rosary_stats" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Enable insert for users based on user_id" ON "public"."groups" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Enable read access for all users" ON "public"."event_messages_actions" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."events" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."exam_consciousness" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."groups" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."posts" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."profiles" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."rosary_stats" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."youtube" FOR SELECT USING (true);



CREATE POLICY "Enable read for authenticated users only" ON "public"."event_messages" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable the user to update own message" ON "public"."event_messages" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Enable to update" ON "public"."event_messages_actions" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Users can delete their own notification settings" ON "public"."notification_settings" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own subscriptions" ON "public"."push_subscriptions" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert global prayer sessions" ON "public"."global_prayer_sessions" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can insert their own badges" ON "public"."user_badges" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own milestones" ON "public"."user_milestones" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own notification settings" ON "public"."notification_settings" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can insert their own subscriptions" ON "public"."push_subscriptions" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update global prayer sessions" ON "public"."global_prayer_sessions" FOR UPDATE TO "authenticated" USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can update their own badges" ON "public"."user_badges" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own milestones" ON "public"."user_milestones" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own notification settings" ON "public"."notification_settings" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own subscriptions" ON "public"."push_subscriptions" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view global prayer sessions" ON "public"."global_prayer_sessions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Users can view their own badges" ON "public"."user_badges" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own milestones" ON "public"."user_milestones" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own notification settings" ON "public"."notification_settings" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own subscriptions" ON "public"."push_subscriptions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "all if userId is uuid1 and uuid2 " ON "public"."friend_requests" TO "authenticated" USING ((("auth"."uid"() = "uuid1") OR ("auth"."uid"() = "uuid2")));



CREATE POLICY "allow all if userId is uuid1 or uuid2" ON "public"."friends" TO "authenticated" USING ((("auth"."uid"() = "uuid1") OR ("auth"."uid"() = "uuid2")));



ALTER TABLE "public"."badge_definitions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."challenges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."churches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_messages_actions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."exam_consciousness" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."friend_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."friends" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."global_prayer_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "gps_insert_auth" ON "public"."global_prayer_sessions" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "gps_select_all" ON "public"."global_prayer_sessions" FOR SELECT USING (true);



CREATE POLICY "gps_update_service" ON "public"."global_prayer_sessions" FOR UPDATE USING ((("current_setting"('role'::"text", true) = 'service_role'::"text") OR ("auth"."role"() = 'service_role'::"text")));



ALTER TABLE "public"."groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."posts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prayer_locations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "prayer_locations_insert_service" ON "public"."prayer_locations" FOR INSERT WITH CHECK ((("current_setting"('role'::"text", true) = 'service_role'::"text") OR ("auth"."role"() = 'service_role'::"text")));



CREATE POLICY "prayer_locations_select_all" ON "public"."prayer_locations" FOR SELECT USING (true);



CREATE POLICY "prayer_locations_update_service" ON "public"."prayer_locations" FOR UPDATE USING ((("current_setting"('role'::"text", true) = 'service_role'::"text") OR ("auth"."role"() = 'service_role'::"text")));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."push_subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."rosary_stats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."scripture_completions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "scripture_completions_insert" ON "public"."scripture_completions" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "scripture_completions_select" ON "public"."scripture_completions" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."user_badges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_milestones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_xp" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_xp_insert_own" ON "public"."user_xp" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "user_xp_select_own" ON "public"."user_xp" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "user_xp_update_own" ON "public"."user_xp" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."xp_events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "xp_events_select_own" ON "public"."xp_events" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."xp_levels_config" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "xp_levels_config_read" ON "public"."xp_levels_config" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."xp_rules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "xp_rules_read" ON "public"."xp_rules" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."youtube" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."event_messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."profiles";






GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT USAGE ON SCHEMA "public" TO "postgres";























































































































































































GRANT ALL ON FUNCTION "public"."admin_retention_d1"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_retention_d1"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_retention_d1"() TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_retention_d30"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_retention_d30"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_retention_d30"() TO "service_role";



GRANT ALL ON FUNCTION "public"."admin_retention_d7"() TO "anon";
GRANT ALL ON FUNCTION "public"."admin_retention_d7"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."admin_retention_d7"() TO "service_role";



GRANT ALL ON FUNCTION "public"."award_xp"("p_user_id" "uuid", "p_action_type" "text", "p_metadata" "jsonb", "p_idempotency_key" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."award_xp"("p_user_id" "uuid", "p_action_type" "text", "p_metadata" "jsonb", "p_idempotency_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."award_xp"("p_user_id" "uuid", "p_action_type" "text", "p_metadata" "jsonb", "p_idempotency_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."becoming_friends"() TO "anon";
GRANT ALL ON FUNCTION "public"."becoming_friends"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."becoming_friends"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_xp_level"("p_total_xp" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_xp_level"("p_total_xp" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_xp_level"("p_total_xp" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_user_xp_row"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_user_xp_row"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_user_xp_row"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."expire_stale_prayer_sessions"() TO "anon";
GRANT ALL ON FUNCTION "public"."expire_stale_prayer_sessions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."expire_stale_prayer_sessions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_all_rosary_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_rosary_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_rosary_count"() TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."prayer_locations" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."prayer_locations" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."prayer_locations" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_prayer_map_cities"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_prayer_map_cities"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_prayer_map_cities"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_profiles_by_user_ids"("user_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."get_profiles_by_user_ids"("user_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_profiles_by_user_ids"("user_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_top_10_user_ids"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_top_10_user_ids"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_top_10_user_ids"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_top_10_user_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_top_10_user_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_top_10_user_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_achievement_dashboard"("target_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_achievement_dashboard"("target_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_achievement_dashboard"("target_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_weekly_leaderboard_me"("p_user_id" "uuid", "p_week_start" "date", "p_week_end" "date", "p_neighbors" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_weekly_leaderboard_me"("p_user_id" "uuid", "p_week_start" "date", "p_week_end" "date", "p_neighbors" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_weekly_leaderboard_me"("p_user_id" "uuid", "p_week_start" "date", "p_week_end" "date", "p_neighbors" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."global_prayer_sessions_set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."global_prayer_sessions_set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."global_prayer_sessions_set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_prayer_count"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" numeric, "p_longitude" numeric, "p_increment" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."increment_prayer_count"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" numeric, "p_longitude" numeric, "p_increment" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_prayer_count"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" numeric, "p_longitude" numeric, "p_increment" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."insert_into_rosary_stats"("p_user_id" "uuid", "p_join_rosary_user_id" "uuid", "p_completed_at" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."insert_into_rosary_stats"("p_user_id" "uuid", "p_join_rosary_user_id" "uuid", "p_completed_at" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."insert_into_rosary_stats"("p_user_id" "uuid", "p_join_rosary_user_id" "uuid", "p_completed_at" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."join_global_prayer_session"("p_session_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."join_global_prayer_session"("p_session_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_global_prayer_session"("p_session_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_existing_friend_requests"() TO "anon";
GRANT ALL ON FUNCTION "public"."remove_existing_friend_requests"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_existing_friend_requests"() TO "service_role";



GRANT ALL ON FUNCTION "public"."search_profiles"("search_text" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."search_profiles"("search_text" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_profiles"("search_text" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_daily_scripture_cache_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_daily_scripture_cache_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_daily_scripture_cache_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_xp_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_xp_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_xp_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."snapshot_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."snapshot_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."snapshot_weekly_leaderboard"("p_week_start" "date", "p_week_end" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_global_prayer_session"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" double precision, "p_longitude" double precision, "p_prayer_type" "text", "p_created_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_global_prayer_session"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" double precision, "p_longitude" double precision, "p_prayer_type" "text", "p_created_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_global_prayer_session"("p_city" "text", "p_country_code" "text", "p_country_name" "text", "p_latitude" double precision, "p_longitude" double precision, "p_prayer_type" "text", "p_created_by" "uuid") TO "service_role";






























GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."exam_consciousness" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."exam_consciousness" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."exam_consciousness" TO "service_role";



GRANT ALL ON SEQUENCE "public"."ConscienceExam_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."ConscienceExam_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."ConscienceExam_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."events" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."events" TO "service_role";



GRANT ALL ON SEQUENCE "public"."Events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Events_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."badge_definitions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."badge_definitions" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."badge_definitions" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."challenges" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."challenges" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."challenges" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."churches" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."churches" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."churches" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."daily_scripture_cache" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."daily_scripture_cache" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."daily_scripture_cache" TO "service_role";



GRANT ALL ON SEQUENCE "public"."daily_scripture_cache_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."daily_scripture_cache_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."daily_scripture_cache_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."daily_scripture_cron_runs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."daily_scripture_cron_runs" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."daily_scripture_cron_runs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."daily_scripture_cron_runs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."daily_scripture_cron_runs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."daily_scripture_cron_runs_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_messages" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_messages" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_messages" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_messages_actions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_messages_actions" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."event_messages_actions" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."friend_requests" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."friend_requests" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."friend_requests" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."friends" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."friends" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."friends" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."global_prayer_sessions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."global_prayer_sessions" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."global_prayer_sessions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."global_prayer_sessions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_prayer_sessions_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."global_prayer_sessions_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."groups" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."groups" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."groups" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."latest_event" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."latest_event" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."latest_event" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboard_config" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboard_config" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboard_config" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboard_history" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboard_history" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboard_history" TO "service_role";



GRANT ALL ON SEQUENCE "public"."leaderboard_history_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."leaderboard_history_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."leaderboard_history_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboards_weekly" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboards_weekly" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."leaderboards_weekly" TO "service_role";



GRANT ALL ON SEQUENCE "public"."leaderboards_weekly_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."leaderboards_weekly_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."leaderboards_weekly_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notification_settings" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notification_settings" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."notification_settings" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."posts" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."posts" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."posts" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."prayer_locations_by_country" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."prayer_locations_by_country" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."prayer_locations_by_country" TO "service_role";



GRANT ALL ON SEQUENCE "public"."prayer_locations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."prayer_locations_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."prayer_locations_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profiles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."push_subscriptions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."push_subscriptions" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."push_subscriptions" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."rosary_stats" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."rosary_stats" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."rosary_stats" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."scripture_completions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."scripture_completions" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."scripture_completions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."scripture_completions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."scripture_completions_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."scripture_completions_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_badges" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_badges" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_badges" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_milestones" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_milestones" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_milestones" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_xp" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_xp" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."user_xp" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_events" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_events" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_events" TO "service_role";



GRANT ALL ON SEQUENCE "public"."xp_events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."xp_events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."xp_events_id_seq" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_levels_config" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_levels_config" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_levels_config" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_rules" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_rules" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."xp_rules" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."youtube" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."youtube" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "public"."youtube" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "service_role";































