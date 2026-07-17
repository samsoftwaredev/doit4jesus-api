create schema if not exists "app";

drop trigger if exists "trg_daily_scripture_cache_updated_at" on "public"."daily_scripture_cache";

drop trigger if exists "friend_request_accepted" on "public"."friend_requests";

drop trigger if exists "remove_friend_request_if_they_are_friends" on "public"."friend_requests";

drop trigger if exists "trigger_global_prayer_sessions_updated_at" on "public"."global_prayer_sessions";

drop trigger if exists "Invite link user joined app" on "public"."profiles";

drop trigger if exists "set_user_xp_updated_at" on "public"."user_xp";

drop trigger if exists "set_xp_rules_updated_at" on "public"."xp_rules";

drop policy "Badge definitions are viewable by authenticated users" on "public"."badge_definitions";

drop policy "Auth Users Can View Challenge" on "public"."challenges";

drop policy "Enable insert for authenticated users only" on "public"."event_messages";

drop policy "Enable read for authenticated users only" on "public"."event_messages";

drop policy "Enable the user to update own message" on "public"."event_messages";

drop policy "Enable insert for authenticated users only" on "public"."event_messages_actions";

drop policy "Enable read access for all users" on "public"."event_messages_actions";

drop policy "Enable to update" on "public"."event_messages_actions";

drop policy "Enable read access for all users" on "public"."events";

drop policy "Enable read access for all users" on "public"."exam_consciousness";

drop policy "all if userId is uuid1 and uuid2 " on "public"."friend_requests";

drop policy "allow all if userId is uuid1 or uuid2" on "public"."friends";

drop policy "Users can insert global prayer sessions" on "public"."global_prayer_sessions";

drop policy "Users can update global prayer sessions" on "public"."global_prayer_sessions";

drop policy "Users can view global prayer sessions" on "public"."global_prayer_sessions";

drop policy "gps_insert_auth" on "public"."global_prayer_sessions";

drop policy "gps_select_all" on "public"."global_prayer_sessions";

drop policy "gps_update_service" on "public"."global_prayer_sessions";

drop policy "Enable insert for users based on user_id" on "public"."groups";

drop policy "Enable read access for all users" on "public"."groups";

drop policy "Users can delete their own notification settings" on "public"."notification_settings";

drop policy "Users can insert their own notification settings" on "public"."notification_settings";

drop policy "Users can update their own notification settings" on "public"."notification_settings";

drop policy "Users can view their own notification settings" on "public"."notification_settings";

drop policy "Enable read access for all users" on "public"."posts";

drop policy "prayer_locations_insert_service" on "public"."prayer_locations";

drop policy "prayer_locations_select_all" on "public"."prayer_locations";

drop policy "prayer_locations_update_service" on "public"."prayer_locations";

drop policy "Enable read access for all users" on "public"."profiles";

drop policy "Users can insert their own profile." on "public"."profiles";

drop policy "Users can update own profile." on "public"."profiles";

drop policy "Users can delete their own subscriptions" on "public"."push_subscriptions";

drop policy "Users can insert their own subscriptions" on "public"."push_subscriptions";

drop policy "Users can update their own subscriptions" on "public"."push_subscriptions";

drop policy "Users can view their own subscriptions" on "public"."push_subscriptions";

drop policy "Enable insert for authenticated users only" on "public"."rosary_stats";

drop policy "Enable read access for all users" on "public"."rosary_stats";

drop policy "scripture_completions_insert" on "public"."scripture_completions";

drop policy "scripture_completions_select" on "public"."scripture_completions";

drop policy "Users can insert their own badges" on "public"."user_badges";

drop policy "Users can update their own badges" on "public"."user_badges";

drop policy "Users can view their own badges" on "public"."user_badges";

drop policy "Users can insert their own milestones" on "public"."user_milestones";

drop policy "Users can update their own milestones" on "public"."user_milestones";

drop policy "Users can view their own milestones" on "public"."user_milestones";

drop policy "user_xp_insert_own" on "public"."user_xp";

drop policy "user_xp_select_own" on "public"."user_xp";

drop policy "user_xp_update_own" on "public"."user_xp";

drop policy "xp_events_select_own" on "public"."xp_events";

drop policy "xp_levels_config_read" on "public"."xp_levels_config";

drop policy "xp_rules_read" on "public"."xp_rules";

drop policy "Enable read access for all users" on "public"."youtube";

revoke delete on table "public"."badge_definitions" from "anon";

revoke insert on table "public"."badge_definitions" from "anon";

revoke references on table "public"."badge_definitions" from "anon";

revoke select on table "public"."badge_definitions" from "anon";

revoke trigger on table "public"."badge_definitions" from "anon";

revoke truncate on table "public"."badge_definitions" from "anon";

revoke update on table "public"."badge_definitions" from "anon";

revoke delete on table "public"."badge_definitions" from "authenticated";

revoke insert on table "public"."badge_definitions" from "authenticated";

revoke references on table "public"."badge_definitions" from "authenticated";

revoke select on table "public"."badge_definitions" from "authenticated";

revoke trigger on table "public"."badge_definitions" from "authenticated";

revoke truncate on table "public"."badge_definitions" from "authenticated";

revoke update on table "public"."badge_definitions" from "authenticated";

revoke delete on table "public"."badge_definitions" from "service_role";

revoke insert on table "public"."badge_definitions" from "service_role";

revoke references on table "public"."badge_definitions" from "service_role";

revoke select on table "public"."badge_definitions" from "service_role";

revoke trigger on table "public"."badge_definitions" from "service_role";

revoke truncate on table "public"."badge_definitions" from "service_role";

revoke update on table "public"."badge_definitions" from "service_role";

revoke delete on table "public"."challenges" from "anon";

revoke insert on table "public"."challenges" from "anon";

revoke references on table "public"."challenges" from "anon";

revoke select on table "public"."challenges" from "anon";

revoke trigger on table "public"."challenges" from "anon";

revoke truncate on table "public"."challenges" from "anon";

revoke update on table "public"."challenges" from "anon";

revoke delete on table "public"."challenges" from "authenticated";

revoke insert on table "public"."challenges" from "authenticated";

revoke references on table "public"."challenges" from "authenticated";

revoke select on table "public"."challenges" from "authenticated";

revoke trigger on table "public"."challenges" from "authenticated";

revoke truncate on table "public"."challenges" from "authenticated";

revoke update on table "public"."challenges" from "authenticated";

revoke delete on table "public"."challenges" from "service_role";

revoke insert on table "public"."challenges" from "service_role";

revoke references on table "public"."challenges" from "service_role";

revoke select on table "public"."challenges" from "service_role";

revoke trigger on table "public"."challenges" from "service_role";

revoke truncate on table "public"."challenges" from "service_role";

revoke update on table "public"."challenges" from "service_role";

revoke delete on table "public"."churches" from "anon";

revoke insert on table "public"."churches" from "anon";

revoke references on table "public"."churches" from "anon";

revoke select on table "public"."churches" from "anon";

revoke trigger on table "public"."churches" from "anon";

revoke truncate on table "public"."churches" from "anon";

revoke update on table "public"."churches" from "anon";

revoke delete on table "public"."churches" from "authenticated";

revoke insert on table "public"."churches" from "authenticated";

revoke references on table "public"."churches" from "authenticated";

revoke select on table "public"."churches" from "authenticated";

revoke trigger on table "public"."churches" from "authenticated";

revoke truncate on table "public"."churches" from "authenticated";

revoke update on table "public"."churches" from "authenticated";

revoke delete on table "public"."churches" from "service_role";

revoke insert on table "public"."churches" from "service_role";

revoke references on table "public"."churches" from "service_role";

revoke select on table "public"."churches" from "service_role";

revoke trigger on table "public"."churches" from "service_role";

revoke truncate on table "public"."churches" from "service_role";

revoke update on table "public"."churches" from "service_role";

revoke delete on table "public"."daily_scripture_cache" from "anon";

revoke insert on table "public"."daily_scripture_cache" from "anon";

revoke references on table "public"."daily_scripture_cache" from "anon";

revoke select on table "public"."daily_scripture_cache" from "anon";

revoke trigger on table "public"."daily_scripture_cache" from "anon";

revoke truncate on table "public"."daily_scripture_cache" from "anon";

revoke update on table "public"."daily_scripture_cache" from "anon";

revoke delete on table "public"."daily_scripture_cache" from "authenticated";

revoke insert on table "public"."daily_scripture_cache" from "authenticated";

revoke references on table "public"."daily_scripture_cache" from "authenticated";

revoke select on table "public"."daily_scripture_cache" from "authenticated";

revoke trigger on table "public"."daily_scripture_cache" from "authenticated";

revoke truncate on table "public"."daily_scripture_cache" from "authenticated";

revoke update on table "public"."daily_scripture_cache" from "authenticated";

revoke delete on table "public"."daily_scripture_cache" from "service_role";

revoke insert on table "public"."daily_scripture_cache" from "service_role";

revoke references on table "public"."daily_scripture_cache" from "service_role";

revoke select on table "public"."daily_scripture_cache" from "service_role";

revoke trigger on table "public"."daily_scripture_cache" from "service_role";

revoke truncate on table "public"."daily_scripture_cache" from "service_role";

revoke update on table "public"."daily_scripture_cache" from "service_role";

revoke delete on table "public"."daily_scripture_cron_runs" from "anon";

revoke insert on table "public"."daily_scripture_cron_runs" from "anon";

revoke references on table "public"."daily_scripture_cron_runs" from "anon";

revoke select on table "public"."daily_scripture_cron_runs" from "anon";

revoke trigger on table "public"."daily_scripture_cron_runs" from "anon";

revoke truncate on table "public"."daily_scripture_cron_runs" from "anon";

revoke update on table "public"."daily_scripture_cron_runs" from "anon";

revoke delete on table "public"."daily_scripture_cron_runs" from "authenticated";

revoke insert on table "public"."daily_scripture_cron_runs" from "authenticated";

revoke references on table "public"."daily_scripture_cron_runs" from "authenticated";

revoke select on table "public"."daily_scripture_cron_runs" from "authenticated";

revoke trigger on table "public"."daily_scripture_cron_runs" from "authenticated";

revoke truncate on table "public"."daily_scripture_cron_runs" from "authenticated";

revoke update on table "public"."daily_scripture_cron_runs" from "authenticated";

revoke delete on table "public"."daily_scripture_cron_runs" from "service_role";

revoke insert on table "public"."daily_scripture_cron_runs" from "service_role";

revoke references on table "public"."daily_scripture_cron_runs" from "service_role";

revoke select on table "public"."daily_scripture_cron_runs" from "service_role";

revoke trigger on table "public"."daily_scripture_cron_runs" from "service_role";

revoke truncate on table "public"."daily_scripture_cron_runs" from "service_role";

revoke update on table "public"."daily_scripture_cron_runs" from "service_role";

revoke delete on table "public"."event_messages" from "anon";

revoke insert on table "public"."event_messages" from "anon";

revoke references on table "public"."event_messages" from "anon";

revoke select on table "public"."event_messages" from "anon";

revoke trigger on table "public"."event_messages" from "anon";

revoke truncate on table "public"."event_messages" from "anon";

revoke update on table "public"."event_messages" from "anon";

revoke delete on table "public"."event_messages" from "authenticated";

revoke insert on table "public"."event_messages" from "authenticated";

revoke references on table "public"."event_messages" from "authenticated";

revoke select on table "public"."event_messages" from "authenticated";

revoke trigger on table "public"."event_messages" from "authenticated";

revoke truncate on table "public"."event_messages" from "authenticated";

revoke update on table "public"."event_messages" from "authenticated";

revoke delete on table "public"."event_messages" from "service_role";

revoke insert on table "public"."event_messages" from "service_role";

revoke references on table "public"."event_messages" from "service_role";

revoke select on table "public"."event_messages" from "service_role";

revoke trigger on table "public"."event_messages" from "service_role";

revoke truncate on table "public"."event_messages" from "service_role";

revoke update on table "public"."event_messages" from "service_role";

revoke delete on table "public"."event_messages_actions" from "anon";

revoke insert on table "public"."event_messages_actions" from "anon";

revoke references on table "public"."event_messages_actions" from "anon";

revoke select on table "public"."event_messages_actions" from "anon";

revoke trigger on table "public"."event_messages_actions" from "anon";

revoke truncate on table "public"."event_messages_actions" from "anon";

revoke update on table "public"."event_messages_actions" from "anon";

revoke delete on table "public"."event_messages_actions" from "authenticated";

revoke insert on table "public"."event_messages_actions" from "authenticated";

revoke references on table "public"."event_messages_actions" from "authenticated";

revoke select on table "public"."event_messages_actions" from "authenticated";

revoke trigger on table "public"."event_messages_actions" from "authenticated";

revoke truncate on table "public"."event_messages_actions" from "authenticated";

revoke update on table "public"."event_messages_actions" from "authenticated";

revoke delete on table "public"."event_messages_actions" from "service_role";

revoke insert on table "public"."event_messages_actions" from "service_role";

revoke references on table "public"."event_messages_actions" from "service_role";

revoke select on table "public"."event_messages_actions" from "service_role";

revoke trigger on table "public"."event_messages_actions" from "service_role";

revoke truncate on table "public"."event_messages_actions" from "service_role";

revoke update on table "public"."event_messages_actions" from "service_role";

revoke delete on table "public"."events" from "anon";

revoke insert on table "public"."events" from "anon";

revoke references on table "public"."events" from "anon";

revoke select on table "public"."events" from "anon";

revoke trigger on table "public"."events" from "anon";

revoke truncate on table "public"."events" from "anon";

revoke update on table "public"."events" from "anon";

revoke delete on table "public"."events" from "authenticated";

revoke insert on table "public"."events" from "authenticated";

revoke references on table "public"."events" from "authenticated";

revoke select on table "public"."events" from "authenticated";

revoke trigger on table "public"."events" from "authenticated";

revoke truncate on table "public"."events" from "authenticated";

revoke update on table "public"."events" from "authenticated";

revoke delete on table "public"."events" from "service_role";

revoke insert on table "public"."events" from "service_role";

revoke references on table "public"."events" from "service_role";

revoke select on table "public"."events" from "service_role";

revoke trigger on table "public"."events" from "service_role";

revoke truncate on table "public"."events" from "service_role";

revoke update on table "public"."events" from "service_role";

revoke delete on table "public"."exam_consciousness" from "anon";

revoke insert on table "public"."exam_consciousness" from "anon";

revoke references on table "public"."exam_consciousness" from "anon";

revoke select on table "public"."exam_consciousness" from "anon";

revoke trigger on table "public"."exam_consciousness" from "anon";

revoke truncate on table "public"."exam_consciousness" from "anon";

revoke update on table "public"."exam_consciousness" from "anon";

revoke delete on table "public"."exam_consciousness" from "authenticated";

revoke insert on table "public"."exam_consciousness" from "authenticated";

revoke references on table "public"."exam_consciousness" from "authenticated";

revoke select on table "public"."exam_consciousness" from "authenticated";

revoke trigger on table "public"."exam_consciousness" from "authenticated";

revoke truncate on table "public"."exam_consciousness" from "authenticated";

revoke update on table "public"."exam_consciousness" from "authenticated";

revoke delete on table "public"."exam_consciousness" from "service_role";

revoke insert on table "public"."exam_consciousness" from "service_role";

revoke references on table "public"."exam_consciousness" from "service_role";

revoke select on table "public"."exam_consciousness" from "service_role";

revoke trigger on table "public"."exam_consciousness" from "service_role";

revoke truncate on table "public"."exam_consciousness" from "service_role";

revoke update on table "public"."exam_consciousness" from "service_role";

revoke delete on table "public"."friend_requests" from "anon";

revoke insert on table "public"."friend_requests" from "anon";

revoke references on table "public"."friend_requests" from "anon";

revoke select on table "public"."friend_requests" from "anon";

revoke trigger on table "public"."friend_requests" from "anon";

revoke truncate on table "public"."friend_requests" from "anon";

revoke update on table "public"."friend_requests" from "anon";

revoke delete on table "public"."friend_requests" from "authenticated";

revoke insert on table "public"."friend_requests" from "authenticated";

revoke references on table "public"."friend_requests" from "authenticated";

revoke select on table "public"."friend_requests" from "authenticated";

revoke trigger on table "public"."friend_requests" from "authenticated";

revoke truncate on table "public"."friend_requests" from "authenticated";

revoke update on table "public"."friend_requests" from "authenticated";

revoke delete on table "public"."friend_requests" from "service_role";

revoke insert on table "public"."friend_requests" from "service_role";

revoke references on table "public"."friend_requests" from "service_role";

revoke select on table "public"."friend_requests" from "service_role";

revoke trigger on table "public"."friend_requests" from "service_role";

revoke truncate on table "public"."friend_requests" from "service_role";

revoke update on table "public"."friend_requests" from "service_role";

revoke delete on table "public"."friends" from "anon";

revoke insert on table "public"."friends" from "anon";

revoke references on table "public"."friends" from "anon";

revoke select on table "public"."friends" from "anon";

revoke trigger on table "public"."friends" from "anon";

revoke truncate on table "public"."friends" from "anon";

revoke update on table "public"."friends" from "anon";

revoke delete on table "public"."friends" from "authenticated";

revoke insert on table "public"."friends" from "authenticated";

revoke references on table "public"."friends" from "authenticated";

revoke select on table "public"."friends" from "authenticated";

revoke trigger on table "public"."friends" from "authenticated";

revoke truncate on table "public"."friends" from "authenticated";

revoke update on table "public"."friends" from "authenticated";

revoke delete on table "public"."friends" from "service_role";

revoke insert on table "public"."friends" from "service_role";

revoke references on table "public"."friends" from "service_role";

revoke select on table "public"."friends" from "service_role";

revoke trigger on table "public"."friends" from "service_role";

revoke truncate on table "public"."friends" from "service_role";

revoke update on table "public"."friends" from "service_role";

revoke delete on table "public"."global_prayer_sessions" from "anon";

revoke insert on table "public"."global_prayer_sessions" from "anon";

revoke references on table "public"."global_prayer_sessions" from "anon";

revoke select on table "public"."global_prayer_sessions" from "anon";

revoke trigger on table "public"."global_prayer_sessions" from "anon";

revoke truncate on table "public"."global_prayer_sessions" from "anon";

revoke update on table "public"."global_prayer_sessions" from "anon";

revoke delete on table "public"."global_prayer_sessions" from "authenticated";

revoke insert on table "public"."global_prayer_sessions" from "authenticated";

revoke references on table "public"."global_prayer_sessions" from "authenticated";

revoke select on table "public"."global_prayer_sessions" from "authenticated";

revoke trigger on table "public"."global_prayer_sessions" from "authenticated";

revoke truncate on table "public"."global_prayer_sessions" from "authenticated";

revoke update on table "public"."global_prayer_sessions" from "authenticated";

revoke delete on table "public"."global_prayer_sessions" from "service_role";

revoke insert on table "public"."global_prayer_sessions" from "service_role";

revoke references on table "public"."global_prayer_sessions" from "service_role";

revoke select on table "public"."global_prayer_sessions" from "service_role";

revoke trigger on table "public"."global_prayer_sessions" from "service_role";

revoke truncate on table "public"."global_prayer_sessions" from "service_role";

revoke update on table "public"."global_prayer_sessions" from "service_role";

revoke delete on table "public"."groups" from "anon";

revoke insert on table "public"."groups" from "anon";

revoke references on table "public"."groups" from "anon";

revoke select on table "public"."groups" from "anon";

revoke trigger on table "public"."groups" from "anon";

revoke truncate on table "public"."groups" from "anon";

revoke update on table "public"."groups" from "anon";

revoke delete on table "public"."groups" from "authenticated";

revoke insert on table "public"."groups" from "authenticated";

revoke references on table "public"."groups" from "authenticated";

revoke select on table "public"."groups" from "authenticated";

revoke trigger on table "public"."groups" from "authenticated";

revoke truncate on table "public"."groups" from "authenticated";

revoke update on table "public"."groups" from "authenticated";

revoke delete on table "public"."groups" from "service_role";

revoke insert on table "public"."groups" from "service_role";

revoke references on table "public"."groups" from "service_role";

revoke select on table "public"."groups" from "service_role";

revoke trigger on table "public"."groups" from "service_role";

revoke truncate on table "public"."groups" from "service_role";

revoke update on table "public"."groups" from "service_role";

revoke delete on table "public"."leaderboard_config" from "anon";

revoke insert on table "public"."leaderboard_config" from "anon";

revoke references on table "public"."leaderboard_config" from "anon";

revoke select on table "public"."leaderboard_config" from "anon";

revoke trigger on table "public"."leaderboard_config" from "anon";

revoke truncate on table "public"."leaderboard_config" from "anon";

revoke update on table "public"."leaderboard_config" from "anon";

revoke delete on table "public"."leaderboard_config" from "authenticated";

revoke insert on table "public"."leaderboard_config" from "authenticated";

revoke references on table "public"."leaderboard_config" from "authenticated";

revoke select on table "public"."leaderboard_config" from "authenticated";

revoke trigger on table "public"."leaderboard_config" from "authenticated";

revoke truncate on table "public"."leaderboard_config" from "authenticated";

revoke update on table "public"."leaderboard_config" from "authenticated";

revoke delete on table "public"."leaderboard_config" from "service_role";

revoke insert on table "public"."leaderboard_config" from "service_role";

revoke references on table "public"."leaderboard_config" from "service_role";

revoke select on table "public"."leaderboard_config" from "service_role";

revoke trigger on table "public"."leaderboard_config" from "service_role";

revoke truncate on table "public"."leaderboard_config" from "service_role";

revoke update on table "public"."leaderboard_config" from "service_role";

revoke delete on table "public"."leaderboard_history" from "anon";

revoke insert on table "public"."leaderboard_history" from "anon";

revoke references on table "public"."leaderboard_history" from "anon";

revoke select on table "public"."leaderboard_history" from "anon";

revoke trigger on table "public"."leaderboard_history" from "anon";

revoke truncate on table "public"."leaderboard_history" from "anon";

revoke update on table "public"."leaderboard_history" from "anon";

revoke delete on table "public"."leaderboard_history" from "authenticated";

revoke insert on table "public"."leaderboard_history" from "authenticated";

revoke references on table "public"."leaderboard_history" from "authenticated";

revoke select on table "public"."leaderboard_history" from "authenticated";

revoke trigger on table "public"."leaderboard_history" from "authenticated";

revoke truncate on table "public"."leaderboard_history" from "authenticated";

revoke update on table "public"."leaderboard_history" from "authenticated";

revoke delete on table "public"."leaderboard_history" from "service_role";

revoke insert on table "public"."leaderboard_history" from "service_role";

revoke references on table "public"."leaderboard_history" from "service_role";

revoke select on table "public"."leaderboard_history" from "service_role";

revoke trigger on table "public"."leaderboard_history" from "service_role";

revoke truncate on table "public"."leaderboard_history" from "service_role";

revoke update on table "public"."leaderboard_history" from "service_role";

revoke delete on table "public"."leaderboards_weekly" from "anon";

revoke insert on table "public"."leaderboards_weekly" from "anon";

revoke references on table "public"."leaderboards_weekly" from "anon";

revoke select on table "public"."leaderboards_weekly" from "anon";

revoke trigger on table "public"."leaderboards_weekly" from "anon";

revoke truncate on table "public"."leaderboards_weekly" from "anon";

revoke update on table "public"."leaderboards_weekly" from "anon";

revoke delete on table "public"."leaderboards_weekly" from "authenticated";

revoke insert on table "public"."leaderboards_weekly" from "authenticated";

revoke references on table "public"."leaderboards_weekly" from "authenticated";

revoke select on table "public"."leaderboards_weekly" from "authenticated";

revoke trigger on table "public"."leaderboards_weekly" from "authenticated";

revoke truncate on table "public"."leaderboards_weekly" from "authenticated";

revoke update on table "public"."leaderboards_weekly" from "authenticated";

revoke delete on table "public"."leaderboards_weekly" from "service_role";

revoke insert on table "public"."leaderboards_weekly" from "service_role";

revoke references on table "public"."leaderboards_weekly" from "service_role";

revoke select on table "public"."leaderboards_weekly" from "service_role";

revoke trigger on table "public"."leaderboards_weekly" from "service_role";

revoke truncate on table "public"."leaderboards_weekly" from "service_role";

revoke update on table "public"."leaderboards_weekly" from "service_role";

revoke delete on table "public"."notification_settings" from "anon";

revoke insert on table "public"."notification_settings" from "anon";

revoke references on table "public"."notification_settings" from "anon";

revoke select on table "public"."notification_settings" from "anon";

revoke trigger on table "public"."notification_settings" from "anon";

revoke truncate on table "public"."notification_settings" from "anon";

revoke update on table "public"."notification_settings" from "anon";

revoke delete on table "public"."notification_settings" from "authenticated";

revoke insert on table "public"."notification_settings" from "authenticated";

revoke references on table "public"."notification_settings" from "authenticated";

revoke select on table "public"."notification_settings" from "authenticated";

revoke trigger on table "public"."notification_settings" from "authenticated";

revoke truncate on table "public"."notification_settings" from "authenticated";

revoke update on table "public"."notification_settings" from "authenticated";

revoke delete on table "public"."notification_settings" from "service_role";

revoke insert on table "public"."notification_settings" from "service_role";

revoke references on table "public"."notification_settings" from "service_role";

revoke select on table "public"."notification_settings" from "service_role";

revoke trigger on table "public"."notification_settings" from "service_role";

revoke truncate on table "public"."notification_settings" from "service_role";

revoke update on table "public"."notification_settings" from "service_role";

revoke delete on table "public"."posts" from "anon";

revoke insert on table "public"."posts" from "anon";

revoke references on table "public"."posts" from "anon";

revoke select on table "public"."posts" from "anon";

revoke trigger on table "public"."posts" from "anon";

revoke truncate on table "public"."posts" from "anon";

revoke update on table "public"."posts" from "anon";

revoke delete on table "public"."posts" from "authenticated";

revoke insert on table "public"."posts" from "authenticated";

revoke references on table "public"."posts" from "authenticated";

revoke select on table "public"."posts" from "authenticated";

revoke trigger on table "public"."posts" from "authenticated";

revoke truncate on table "public"."posts" from "authenticated";

revoke update on table "public"."posts" from "authenticated";

revoke delete on table "public"."posts" from "service_role";

revoke insert on table "public"."posts" from "service_role";

revoke references on table "public"."posts" from "service_role";

revoke select on table "public"."posts" from "service_role";

revoke trigger on table "public"."posts" from "service_role";

revoke truncate on table "public"."posts" from "service_role";

revoke update on table "public"."posts" from "service_role";

revoke delete on table "public"."prayer_locations" from "anon";

revoke insert on table "public"."prayer_locations" from "anon";

revoke references on table "public"."prayer_locations" from "anon";

revoke select on table "public"."prayer_locations" from "anon";

revoke trigger on table "public"."prayer_locations" from "anon";

revoke truncate on table "public"."prayer_locations" from "anon";

revoke update on table "public"."prayer_locations" from "anon";

revoke delete on table "public"."prayer_locations" from "authenticated";

revoke insert on table "public"."prayer_locations" from "authenticated";

revoke references on table "public"."prayer_locations" from "authenticated";

revoke select on table "public"."prayer_locations" from "authenticated";

revoke trigger on table "public"."prayer_locations" from "authenticated";

revoke truncate on table "public"."prayer_locations" from "authenticated";

revoke update on table "public"."prayer_locations" from "authenticated";

revoke delete on table "public"."prayer_locations" from "service_role";

revoke insert on table "public"."prayer_locations" from "service_role";

revoke references on table "public"."prayer_locations" from "service_role";

revoke select on table "public"."prayer_locations" from "service_role";

revoke trigger on table "public"."prayer_locations" from "service_role";

revoke truncate on table "public"."prayer_locations" from "service_role";

revoke update on table "public"."prayer_locations" from "service_role";

revoke delete on table "public"."profiles" from "anon";

revoke insert on table "public"."profiles" from "anon";

revoke references on table "public"."profiles" from "anon";

revoke select on table "public"."profiles" from "anon";

revoke trigger on table "public"."profiles" from "anon";

revoke truncate on table "public"."profiles" from "anon";

revoke update on table "public"."profiles" from "anon";

revoke delete on table "public"."profiles" from "authenticated";

revoke insert on table "public"."profiles" from "authenticated";

revoke references on table "public"."profiles" from "authenticated";

revoke select on table "public"."profiles" from "authenticated";

revoke trigger on table "public"."profiles" from "authenticated";

revoke truncate on table "public"."profiles" from "authenticated";

revoke update on table "public"."profiles" from "authenticated";

revoke delete on table "public"."profiles" from "service_role";

revoke insert on table "public"."profiles" from "service_role";

revoke references on table "public"."profiles" from "service_role";

revoke select on table "public"."profiles" from "service_role";

revoke trigger on table "public"."profiles" from "service_role";

revoke truncate on table "public"."profiles" from "service_role";

revoke update on table "public"."profiles" from "service_role";

revoke delete on table "public"."push_subscriptions" from "anon";

revoke insert on table "public"."push_subscriptions" from "anon";

revoke references on table "public"."push_subscriptions" from "anon";

revoke select on table "public"."push_subscriptions" from "anon";

revoke trigger on table "public"."push_subscriptions" from "anon";

revoke truncate on table "public"."push_subscriptions" from "anon";

revoke update on table "public"."push_subscriptions" from "anon";

revoke delete on table "public"."push_subscriptions" from "authenticated";

revoke insert on table "public"."push_subscriptions" from "authenticated";

revoke references on table "public"."push_subscriptions" from "authenticated";

revoke select on table "public"."push_subscriptions" from "authenticated";

revoke trigger on table "public"."push_subscriptions" from "authenticated";

revoke truncate on table "public"."push_subscriptions" from "authenticated";

revoke update on table "public"."push_subscriptions" from "authenticated";

revoke delete on table "public"."push_subscriptions" from "service_role";

revoke insert on table "public"."push_subscriptions" from "service_role";

revoke references on table "public"."push_subscriptions" from "service_role";

revoke select on table "public"."push_subscriptions" from "service_role";

revoke trigger on table "public"."push_subscriptions" from "service_role";

revoke truncate on table "public"."push_subscriptions" from "service_role";

revoke update on table "public"."push_subscriptions" from "service_role";

revoke delete on table "public"."rosary_stats" from "anon";

revoke insert on table "public"."rosary_stats" from "anon";

revoke references on table "public"."rosary_stats" from "anon";

revoke select on table "public"."rosary_stats" from "anon";

revoke trigger on table "public"."rosary_stats" from "anon";

revoke truncate on table "public"."rosary_stats" from "anon";

revoke update on table "public"."rosary_stats" from "anon";

revoke delete on table "public"."rosary_stats" from "authenticated";

revoke insert on table "public"."rosary_stats" from "authenticated";

revoke references on table "public"."rosary_stats" from "authenticated";

revoke select on table "public"."rosary_stats" from "authenticated";

revoke trigger on table "public"."rosary_stats" from "authenticated";

revoke truncate on table "public"."rosary_stats" from "authenticated";

revoke update on table "public"."rosary_stats" from "authenticated";

revoke delete on table "public"."rosary_stats" from "service_role";

revoke insert on table "public"."rosary_stats" from "service_role";

revoke references on table "public"."rosary_stats" from "service_role";

revoke select on table "public"."rosary_stats" from "service_role";

revoke trigger on table "public"."rosary_stats" from "service_role";

revoke truncate on table "public"."rosary_stats" from "service_role";

revoke update on table "public"."rosary_stats" from "service_role";

revoke delete on table "public"."scripture_completions" from "anon";

revoke insert on table "public"."scripture_completions" from "anon";

revoke references on table "public"."scripture_completions" from "anon";

revoke select on table "public"."scripture_completions" from "anon";

revoke trigger on table "public"."scripture_completions" from "anon";

revoke truncate on table "public"."scripture_completions" from "anon";

revoke update on table "public"."scripture_completions" from "anon";

revoke delete on table "public"."scripture_completions" from "authenticated";

revoke insert on table "public"."scripture_completions" from "authenticated";

revoke references on table "public"."scripture_completions" from "authenticated";

revoke select on table "public"."scripture_completions" from "authenticated";

revoke trigger on table "public"."scripture_completions" from "authenticated";

revoke truncate on table "public"."scripture_completions" from "authenticated";

revoke update on table "public"."scripture_completions" from "authenticated";

revoke delete on table "public"."scripture_completions" from "service_role";

revoke insert on table "public"."scripture_completions" from "service_role";

revoke references on table "public"."scripture_completions" from "service_role";

revoke select on table "public"."scripture_completions" from "service_role";

revoke trigger on table "public"."scripture_completions" from "service_role";

revoke truncate on table "public"."scripture_completions" from "service_role";

revoke update on table "public"."scripture_completions" from "service_role";

revoke delete on table "public"."user_badges" from "anon";

revoke insert on table "public"."user_badges" from "anon";

revoke references on table "public"."user_badges" from "anon";

revoke select on table "public"."user_badges" from "anon";

revoke trigger on table "public"."user_badges" from "anon";

revoke truncate on table "public"."user_badges" from "anon";

revoke update on table "public"."user_badges" from "anon";

revoke delete on table "public"."user_badges" from "authenticated";

revoke insert on table "public"."user_badges" from "authenticated";

revoke references on table "public"."user_badges" from "authenticated";

revoke select on table "public"."user_badges" from "authenticated";

revoke trigger on table "public"."user_badges" from "authenticated";

revoke truncate on table "public"."user_badges" from "authenticated";

revoke update on table "public"."user_badges" from "authenticated";

revoke delete on table "public"."user_badges" from "service_role";

revoke insert on table "public"."user_badges" from "service_role";

revoke references on table "public"."user_badges" from "service_role";

revoke select on table "public"."user_badges" from "service_role";

revoke trigger on table "public"."user_badges" from "service_role";

revoke truncate on table "public"."user_badges" from "service_role";

revoke update on table "public"."user_badges" from "service_role";

revoke delete on table "public"."user_milestones" from "anon";

revoke insert on table "public"."user_milestones" from "anon";

revoke references on table "public"."user_milestones" from "anon";

revoke select on table "public"."user_milestones" from "anon";

revoke trigger on table "public"."user_milestones" from "anon";

revoke truncate on table "public"."user_milestones" from "anon";

revoke update on table "public"."user_milestones" from "anon";

revoke delete on table "public"."user_milestones" from "authenticated";

revoke insert on table "public"."user_milestones" from "authenticated";

revoke references on table "public"."user_milestones" from "authenticated";

revoke select on table "public"."user_milestones" from "authenticated";

revoke trigger on table "public"."user_milestones" from "authenticated";

revoke truncate on table "public"."user_milestones" from "authenticated";

revoke update on table "public"."user_milestones" from "authenticated";

revoke delete on table "public"."user_milestones" from "service_role";

revoke insert on table "public"."user_milestones" from "service_role";

revoke references on table "public"."user_milestones" from "service_role";

revoke select on table "public"."user_milestones" from "service_role";

revoke trigger on table "public"."user_milestones" from "service_role";

revoke truncate on table "public"."user_milestones" from "service_role";

revoke update on table "public"."user_milestones" from "service_role";

revoke delete on table "public"."user_xp" from "anon";

revoke insert on table "public"."user_xp" from "anon";

revoke references on table "public"."user_xp" from "anon";

revoke select on table "public"."user_xp" from "anon";

revoke trigger on table "public"."user_xp" from "anon";

revoke truncate on table "public"."user_xp" from "anon";

revoke update on table "public"."user_xp" from "anon";

revoke delete on table "public"."user_xp" from "authenticated";

revoke insert on table "public"."user_xp" from "authenticated";

revoke references on table "public"."user_xp" from "authenticated";

revoke select on table "public"."user_xp" from "authenticated";

revoke trigger on table "public"."user_xp" from "authenticated";

revoke truncate on table "public"."user_xp" from "authenticated";

revoke update on table "public"."user_xp" from "authenticated";

revoke delete on table "public"."user_xp" from "service_role";

revoke insert on table "public"."user_xp" from "service_role";

revoke references on table "public"."user_xp" from "service_role";

revoke select on table "public"."user_xp" from "service_role";

revoke trigger on table "public"."user_xp" from "service_role";

revoke truncate on table "public"."user_xp" from "service_role";

revoke update on table "public"."user_xp" from "service_role";

revoke delete on table "public"."xp_events" from "anon";

revoke insert on table "public"."xp_events" from "anon";

revoke references on table "public"."xp_events" from "anon";

revoke select on table "public"."xp_events" from "anon";

revoke trigger on table "public"."xp_events" from "anon";

revoke truncate on table "public"."xp_events" from "anon";

revoke update on table "public"."xp_events" from "anon";

revoke delete on table "public"."xp_events" from "authenticated";

revoke insert on table "public"."xp_events" from "authenticated";

revoke references on table "public"."xp_events" from "authenticated";

revoke select on table "public"."xp_events" from "authenticated";

revoke trigger on table "public"."xp_events" from "authenticated";

revoke truncate on table "public"."xp_events" from "authenticated";

revoke update on table "public"."xp_events" from "authenticated";

revoke delete on table "public"."xp_events" from "service_role";

revoke insert on table "public"."xp_events" from "service_role";

revoke references on table "public"."xp_events" from "service_role";

revoke select on table "public"."xp_events" from "service_role";

revoke trigger on table "public"."xp_events" from "service_role";

revoke truncate on table "public"."xp_events" from "service_role";

revoke update on table "public"."xp_events" from "service_role";

revoke delete on table "public"."xp_levels_config" from "anon";

revoke insert on table "public"."xp_levels_config" from "anon";

revoke references on table "public"."xp_levels_config" from "anon";

revoke select on table "public"."xp_levels_config" from "anon";

revoke trigger on table "public"."xp_levels_config" from "anon";

revoke truncate on table "public"."xp_levels_config" from "anon";

revoke update on table "public"."xp_levels_config" from "anon";

revoke delete on table "public"."xp_levels_config" from "authenticated";

revoke insert on table "public"."xp_levels_config" from "authenticated";

revoke references on table "public"."xp_levels_config" from "authenticated";

revoke select on table "public"."xp_levels_config" from "authenticated";

revoke trigger on table "public"."xp_levels_config" from "authenticated";

revoke truncate on table "public"."xp_levels_config" from "authenticated";

revoke update on table "public"."xp_levels_config" from "authenticated";

revoke delete on table "public"."xp_levels_config" from "service_role";

revoke insert on table "public"."xp_levels_config" from "service_role";

revoke references on table "public"."xp_levels_config" from "service_role";

revoke select on table "public"."xp_levels_config" from "service_role";

revoke trigger on table "public"."xp_levels_config" from "service_role";

revoke truncate on table "public"."xp_levels_config" from "service_role";

revoke update on table "public"."xp_levels_config" from "service_role";

revoke delete on table "public"."xp_rules" from "anon";

revoke insert on table "public"."xp_rules" from "anon";

revoke references on table "public"."xp_rules" from "anon";

revoke select on table "public"."xp_rules" from "anon";

revoke trigger on table "public"."xp_rules" from "anon";

revoke truncate on table "public"."xp_rules" from "anon";

revoke update on table "public"."xp_rules" from "anon";

revoke delete on table "public"."xp_rules" from "authenticated";

revoke insert on table "public"."xp_rules" from "authenticated";

revoke references on table "public"."xp_rules" from "authenticated";

revoke select on table "public"."xp_rules" from "authenticated";

revoke trigger on table "public"."xp_rules" from "authenticated";

revoke truncate on table "public"."xp_rules" from "authenticated";

revoke update on table "public"."xp_rules" from "authenticated";

revoke delete on table "public"."xp_rules" from "service_role";

revoke insert on table "public"."xp_rules" from "service_role";

revoke references on table "public"."xp_rules" from "service_role";

revoke select on table "public"."xp_rules" from "service_role";

revoke trigger on table "public"."xp_rules" from "service_role";

revoke truncate on table "public"."xp_rules" from "service_role";

revoke update on table "public"."xp_rules" from "service_role";

revoke delete on table "public"."youtube" from "anon";

revoke insert on table "public"."youtube" from "anon";

revoke references on table "public"."youtube" from "anon";

revoke select on table "public"."youtube" from "anon";

revoke trigger on table "public"."youtube" from "anon";

revoke truncate on table "public"."youtube" from "anon";

revoke update on table "public"."youtube" from "anon";

revoke delete on table "public"."youtube" from "authenticated";

revoke insert on table "public"."youtube" from "authenticated";

revoke references on table "public"."youtube" from "authenticated";

revoke select on table "public"."youtube" from "authenticated";

revoke trigger on table "public"."youtube" from "authenticated";

revoke truncate on table "public"."youtube" from "authenticated";

revoke update on table "public"."youtube" from "authenticated";

revoke delete on table "public"."youtube" from "service_role";

revoke insert on table "public"."youtube" from "service_role";

revoke references on table "public"."youtube" from "service_role";

revoke select on table "public"."youtube" from "service_role";

revoke trigger on table "public"."youtube" from "service_role";

revoke truncate on table "public"."youtube" from "service_role";

revoke update on table "public"."youtube" from "service_role";

alter table "public"."user_badges" drop constraint "user_badges_badge_key_fkey";

alter table "public"."badge_definitions" drop constraint "badge_definitions_badge_key_key";

alter table "public"."badge_definitions" drop constraint "badge_definitions_requirement_value_check";

alter table "public"."challenges" drop constraint "challenges_goal_amount_check";

alter table "public"."daily_scripture_cache" drop constraint "daily_scripture_cache_fetch_status_check";

alter table "public"."daily_scripture_cache" drop constraint "daily_scripture_cache_locale_check";

alter table "public"."daily_scripture_cache" drop constraint "daily_scripture_cache_scripture_date_locale_key";

alter table "public"."daily_scripture_cron_runs" drop constraint "daily_scripture_cron_runs_locale_check";

alter table "public"."daily_scripture_cron_runs" drop constraint "daily_scripture_cron_runs_status_check";

alter table "public"."event_messages_actions" drop constraint "public_event_messages_actions_id_fkey";

alter table "public"."events" drop constraint "Events_slug_key";

alter table "public"."events" drop constraint "Events_title_check";

alter table "public"."events" drop constraint "events_event_source_fkey";

alter table "public"."friend_requests" drop constraint "friend_requests_friend_id_fkey";

alter table "public"."friend_requests" drop constraint "friend_requests_user_id_fkey";

alter table "public"."friends" drop constraint "Friends_friend_id_fkey";

alter table "public"."friends" drop constraint "Friends_user_id_fkey";

alter table "public"."global_prayer_sessions" drop constraint "global_prayer_sessions_created_by_fkey";

alter table "public"."global_prayer_sessions" drop constraint "global_prayer_sessions_participants_count_check";

alter table "public"."groups" drop constraint "groups_user_id_fkey";

alter table "public"."leaderboard_history" drop constraint "leaderboard_history_user_id_fkey";

alter table "public"."leaderboard_history" drop constraint "leaderboard_history_user_id_week_start_key";

alter table "public"."leaderboards_weekly" drop constraint "leaderboards_weekly_user_id_fkey";

alter table "public"."leaderboards_weekly" drop constraint "leaderboards_weekly_user_id_fkey1";

alter table "public"."leaderboards_weekly" drop constraint "leaderboards_weekly_user_id_week_start_key";

alter table "public"."notification_settings" drop constraint "notification_settings_streak_reminder_hours_before_check";

alter table "public"."notification_settings" drop constraint "notification_settings_user_id_fkey";

alter table "public"."notification_settings" drop constraint "notification_settings_user_id_key";

alter table "public"."posts" drop constraint "posts_slug_key";

alter table "public"."prayer_locations" drop constraint "prayer_locations_city_country_code_key";

alter table "public"."profiles" drop constraint "profiles_id_fkey";

alter table "public"."profiles" drop constraint "profiles_invited_by_fkey";

alter table "public"."profiles" drop constraint "profiles_role_check";

alter table "public"."push_subscriptions" drop constraint "push_subscriptions_user_id_fkey";

alter table "public"."push_subscriptions" drop constraint "push_subscriptions_user_id_key";

alter table "public"."rosary_stats" drop constraint "rosary_stats_join_rosary_user_id_fkey";

alter table "public"."rosary_stats" drop constraint "rosary_stats_user_id_fkey";

alter table "public"."scripture_completions" drop constraint "scripture_completions_user_id_fkey";

alter table "public"."scripture_completions" drop constraint "uq_scripture_user_date";

alter table "public"."user_badges" drop constraint "user_badges_user_id_badge_key_key";

alter table "public"."user_badges" drop constraint "user_badges_user_id_fkey";

alter table "public"."user_milestones" drop constraint "user_milestones_user_id_fkey";

alter table "public"."user_xp" drop constraint "user_xp_total_xp_check";

alter table "public"."user_xp" drop constraint "user_xp_user_id_fkey";

alter table "public"."user_xp" drop constraint "user_xp_user_id_key";

alter table "public"."xp_events" drop constraint "xp_events_user_id_fkey";

alter table "public"."xp_events" drop constraint "xp_events_xp_amount_check";

alter table "public"."xp_levels_config" drop constraint "xp_levels_config_min_xp_check";

alter table "public"."xp_rules" drop constraint "xp_rules_xp_value_check";

alter table "public"."youtube" drop constraint "YouTube_id_key";

drop function if exists "public"."get_prayer_map_cities"();

drop view if exists "public"."latest_event";

drop view if exists "public"."prayer_locations_by_country";

alter table "public"."badge_definitions" drop constraint "badge_definitions_pkey";

alter table "public"."challenges" drop constraint "challenges_pkey";

alter table "public"."churches" drop constraint "church_pkey";

alter table "public"."daily_scripture_cache" drop constraint "daily_scripture_cache_pkey";

alter table "public"."daily_scripture_cron_runs" drop constraint "daily_scripture_cron_runs_pkey";

alter table "public"."event_messages" drop constraint "messages_pkey";

alter table "public"."event_messages_actions" drop constraint "event_messages_actions_pkey";

alter table "public"."events" drop constraint "Events_pkey";

alter table "public"."exam_consciousness" drop constraint "ConscienceExam_pkey";

alter table "public"."friend_requests" drop constraint "friend_requests_pkey";

alter table "public"."friends" drop constraint "friends_pkey";

alter table "public"."global_prayer_sessions" drop constraint "global_prayer_sessions_pkey";

alter table "public"."groups" drop constraint "friends_group_pkey";

alter table "public"."leaderboard_config" drop constraint "leaderboard_config_pkey";

alter table "public"."leaderboard_history" drop constraint "leaderboard_history_pkey";

alter table "public"."leaderboards_weekly" drop constraint "leaderboards_weekly_pkey";

alter table "public"."notification_settings" drop constraint "notification_settings_pkey";

alter table "public"."posts" drop constraint "Post_pkey";

alter table "public"."prayer_locations" drop constraint "prayer_locations_pkey";

alter table "public"."profiles" drop constraint "profiles_pkey";

alter table "public"."push_subscriptions" drop constraint "push_subscriptions_pkey";

alter table "public"."rosary_stats" drop constraint "rosary_stats_pkey";

alter table "public"."scripture_completions" drop constraint "scripture_completions_pkey";

alter table "public"."user_badges" drop constraint "user_badges_pkey";

alter table "public"."user_milestones" drop constraint "user_milestones_pkey";

alter table "public"."user_xp" drop constraint "user_xp_pkey";

alter table "public"."xp_events" drop constraint "xp_events_pkey";

alter table "public"."xp_levels_config" drop constraint "xp_levels_config_pkey";

alter table "public"."xp_rules" drop constraint "xp_rules_pkey";

alter table "public"."youtube" drop constraint "YouTube_pkey";

drop index if exists "public"."ConscienceExam_pkey";

drop index if exists "public"."Events_pkey";

drop index if exists "public"."Events_slug_key";

drop index if exists "public"."Post_pkey";

drop index if exists "public"."YouTube_id_key";

drop index if exists "public"."YouTube_pkey";

drop index if exists "public"."badge_definitions_badge_key_key";

drop index if exists "public"."badge_definitions_pkey";

drop index if exists "public"."challenges_pkey";

drop index if exists "public"."church_pkey";

drop index if exists "public"."daily_scripture_cache_pkey";

drop index if exists "public"."daily_scripture_cache_scripture_date_locale_key";

drop index if exists "public"."daily_scripture_cron_runs_pkey";

drop index if exists "public"."event_messages_actions_pkey";

drop index if exists "public"."friend_requests_pkey";

drop index if exists "public"."friends_group_pkey";

drop index if exists "public"."friends_pkey";

drop index if exists "public"."global_prayer_sessions_active_idx";

drop index if exists "public"."global_prayer_sessions_city_prayer_idx";

drop index if exists "public"."global_prayer_sessions_location_idx";

drop index if exists "public"."global_prayer_sessions_pkey";

drop index if exists "public"."idx_daily_scripture_cache_date_locale";

drop index if exists "public"."idx_daily_scripture_cache_locale_date";

drop index if exists "public"."idx_daily_scripture_cron_runs_created_at";

drop index if exists "public"."idx_daily_scripture_cron_runs_date_locale";

drop index if exists "public"."idx_gps_city_country_active";

drop index if exists "public"."idx_gps_is_active";

drop index if exists "public"."idx_gps_updated_at";

drop index if exists "public"."idx_leaderboard_history_user";

drop index if exists "public"."idx_leaderboards_weekly_user";

drop index if exists "public"."idx_leaderboards_weekly_week";

drop index if exists "public"."idx_notification_settings_enabled";

drop index if exists "public"."idx_notification_settings_user_id";

drop index if exists "public"."idx_prayer_locations_country";

drop index if exists "public"."idx_prayer_locations_country_code";

drop index if exists "public"."idx_prayer_locations_last_updated";

drop index if exists "public"."idx_prayer_locations_prayer_count";

drop index if exists "public"."idx_profiles_last_seen";

drop index if exists "public"."idx_profiles_role";

drop index if exists "public"."idx_push_subscriptions_user_id";

drop index if exists "public"."idx_scripture_completions_user";

drop index if exists "public"."idx_xp_events_user_created";

drop index if exists "public"."leaderboard_config_pkey";

drop index if exists "public"."leaderboard_history_pkey";

drop index if exists "public"."leaderboard_history_user_id_week_start_key";

drop index if exists "public"."leaderboards_weekly_pkey";

drop index if exists "public"."leaderboards_weekly_user_id_week_start_key";

drop index if exists "public"."messages_pkey";

drop index if exists "public"."notification_settings_pkey";

drop index if exists "public"."notification_settings_user_id_key";

drop index if exists "public"."posts_slug_key";

drop index if exists "public"."prayer_locations_city_country_code_key";

drop index if exists "public"."prayer_locations_pkey";

drop index if exists "public"."profiles_pkey";

drop index if exists "public"."push_subscriptions_pkey";

drop index if exists "public"."push_subscriptions_user_id_key";

drop index if exists "public"."rosary_stats_pkey";

drop index if exists "public"."scripture_completions_pkey";

drop index if exists "public"."uq_scripture_user_date";

drop index if exists "public"."user_badges_badge_key_idx";

drop index if exists "public"."user_badges_pkey";

drop index if exists "public"."user_badges_user_id_badge_key_key";

drop index if exists "public"."user_badges_user_id_idx";

drop index if exists "public"."user_milestones_pkey";

drop index if exists "public"."user_xp_pkey";

drop index if exists "public"."user_xp_updated_at_idx";

drop index if exists "public"."user_xp_user_id_idx";

drop index if exists "public"."user_xp_user_id_key";

drop index if exists "public"."xp_events_pkey";

drop index if exists "public"."xp_events_type_idx";

drop index if exists "public"."xp_events_user_id_created_at_idx";

drop index if exists "public"."xp_events_user_idempotency_unique_idx";

drop index if exists "public"."xp_levels_config_min_xp_idx";

drop index if exists "public"."xp_levels_config_pkey";

drop index if exists "public"."xp_rules_pkey";

drop table "public"."badge_definitions";

drop table "public"."challenges";

drop table "public"."churches";

drop table "public"."daily_scripture_cache";

drop table "public"."daily_scripture_cron_runs";

drop table "public"."event_messages";

drop table "public"."event_messages_actions";

drop table "public"."events";

drop table "public"."exam_consciousness";

drop table "public"."friend_requests";

drop table "public"."friends";

drop table "public"."global_prayer_sessions";

drop table "public"."groups";

drop table "public"."leaderboard_config";

drop table "public"."leaderboard_history";

drop table "public"."leaderboards_weekly";

drop table "public"."notification_settings";

drop table "public"."posts";

drop table "public"."prayer_locations";

drop table "public"."profiles";

drop table "public"."push_subscriptions";

drop table "public"."rosary_stats";

drop table "public"."scripture_completions";

drop table "public"."user_badges";

drop table "public"."user_milestones";

drop table "public"."user_xp";

drop table "public"."xp_events";

drop table "public"."xp_levels_config";

drop table "public"."xp_rules";

drop table "public"."youtube";

drop sequence if exists "public"."daily_scripture_cache_id_seq";

drop sequence if exists "public"."daily_scripture_cron_runs_id_seq";

drop sequence if exists "public"."prayer_locations_id_seq";

drop sequence if exists "public"."scripture_completions_id_seq";


