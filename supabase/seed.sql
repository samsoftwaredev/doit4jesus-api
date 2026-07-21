-- Local development seed data for every application-owned table.
--
-- Login credentials (all passwords are 12345678):
--   test@test.com
--   maria@example.com
--   john@example.com
--
-- IDs are intentionally stable so this file can be rerun safely and test
-- fixtures can refer to the same records after every database reset.

begin;

-- ---------------------------------------------------------------------------
-- Authentication users
-- ---------------------------------------------------------------------------

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    'authenticated',
    'authenticated',
    'test@test.com',
    crypt('12345678', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Test User"}'::jsonb,
    now() - interval '90 days',
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-4111-8111-111111111111',
    'authenticated',
    'authenticated',
    'maria@example.com',
    crypt('12345678', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Maria Santos"}'::jsonb,
    now() - interval '60 days',
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-4222-8222-222222222222',
    'authenticated',
    'authenticated',
    'john@example.com',
    crypt('12345678', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"John Paul"}'::jsonb,
    now() - interval '30 days',
    now(),
    '',
    '',
    '',
    ''
  )
on conflict (id) do update
set
  email = excluded.email,
  encrypted_password = excluded.encrypted_password,
  email_confirmed_at = excluded.email_confirmed_at,
  raw_app_meta_data = excluded.raw_app_meta_data,
  raw_user_meta_data = excluded.raw_user_meta_data,
  updated_at = now();

insert into auth.identities (
  id,
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
values
  (
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    '{"sub":"9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002","email":"test@test.com","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now() - interval '90 days',
    now()
  ),
  (
    '11111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    '11111111-1111-4111-8111-111111111111',
    '{"sub":"11111111-1111-4111-8111-111111111111","email":"maria@example.com","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now() - interval '60 days',
    now()
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222',
    '{"sub":"22222222-2222-4222-8222-222222222222","email":"john@example.com","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now() - interval '30 days',
    now()
  )
on conflict (provider_id, provider) do update
set
  user_id = excluded.user_id,
  identity_data = excluded.identity_data,
  last_sign_in_at = excluded.last_sign_in_at,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- Core application data
-- ---------------------------------------------------------------------------

insert into app.countries (code, name, latitude, longitude, is_active)
values
  ('US', 'United States', 39.828300, -98.579500, true),
  ('MX', 'Mexico', 23.634500, -102.552800, true),
  ('VA', 'Vatican City', 41.902900, 12.453400, true)
on conflict (code) do update
set
  name = excluded.name,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  is_active = excluded.is_active;

insert into app.cities (
  id,
  country_code,
  name,
  region_name,
  latitude,
  longitude,
  timezone,
  is_active
)
values
  ('e0000000-0000-4000-8000-000000000001', 'US', 'Austin', 'Texas', 30.267200, -97.743100, 'America/Chicago', true),
  ('e0000000-0000-4000-8000-000000000002', 'US', 'Dallas', 'Texas', 32.776700, -96.797000, 'America/Chicago', true),
  ('e0000000-0000-4000-8000-000000000003', 'MX', 'Mexico City', 'Mexico City', 19.432600, -99.133200, 'America/Mexico_City', true),
  ('e0000000-0000-4000-8000-000000000004', 'VA', 'Vatican City', 'Vatican City', 41.902900, 12.453400, 'Europe/Rome', true)
on conflict (id) do update
set
  country_code = excluded.country_code,
  name = excluded.name,
  region_name = excluded.region_name,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  timezone = excluded.timezone,
  is_active = excluded.is_active;

insert into app.users (
  id,
  email,
  status,
  email_verified_at,
  last_login_at,
  created_at
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'test@test.com', 'active', now() - interval '90 days', now() - interval '2 hours', now() - interval '90 days'),
  ('11111111-1111-4111-8111-111111111111', 'maria@example.com', 'active', now() - interval '60 days', now() - interval '1 hour', now() - interval '60 days'),
  ('22222222-2222-4222-8222-222222222222', 'john@example.com', 'active', now() - interval '30 days', now() - interval '3 hours', now() - interval '30 days')
on conflict (id) do update
set
  email = excluded.email,
  status = excluded.status,
  email_verified_at = excluded.email_verified_at,
  last_login_at = excluded.last_login_at;

insert into app.user_profiles (
  user_id,
  display_name,
  username,
  avatar_url,
  title,
  preferred_language,
  timezone,
  city_id,
  country_code,
  leaderboard_visibility,
  prayer_map_visibility
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'Test User', 'testuser', 'https://i.pravatar.cc/256?u=testuser', 'Faithful Beginner', 'en', 'America/Chicago', 'e0000000-0000-4000-8000-000000000001', 'US', 'public', 'aggregated'),
  ('11111111-1111-4111-8111-111111111111', 'Maria Santos', 'mariasantos', 'https://i.pravatar.cc/256?u=mariasantos', 'Prayer Champion', 'es', 'America/Mexico_City', 'e0000000-0000-4000-8000-000000000003', 'MX', 'public', 'aggregated'),
  ('22222222-2222-4222-8222-222222222222', 'John Paul', 'johnpaul', 'https://i.pravatar.cc/256?u=johnpaul', 'Scripture Seeker', 'en', 'America/Chicago', 'e0000000-0000-4000-8000-000000000002', 'US', 'public', 'aggregated')
on conflict (user_id) do update
set
  display_name = excluded.display_name,
  username = excluded.username,
  avatar_url = excluded.avatar_url,
  title = excluded.title,
  preferred_language = excluded.preferred_language,
  timezone = excluded.timezone,
  city_id = excluded.city_id,
  country_code = excluded.country_code,
  leaderboard_visibility = excluded.leaderboard_visibility,
  prayer_map_visibility = excluded.prayer_map_visibility;

insert into app.notifications (
  id,
  user_id,
  notification_type,
  title,
  body,
  action_url,
  payload,
  read_at,
  created_at
)
values
  ('aa000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'badge_earned', 'Badge earned: First Rosary', 'You earned the First Rosary badge.', '/badges', '{"badgeId":"80000000-0000-4000-8000-000000000001"}'::jsonb, null, now() - interval '2 hours'),
  ('aa000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'challenge_completed', 'Daily Scripture completed', 'Your reward is ready to claim.', '/challenges', '{"assignmentId":"70000000-0000-4000-8000-000000000002"}'::jsonb, now() - interval '22 hours', now() - interval '1 day'),
  ('aa000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'challenge_progress', 'Weekly service progress', 'One of three service acts is complete.', '/challenges', '{"assignmentId":"70000000-0000-4000-8000-000000000003","currentProgress":1}'::jsonb, null, now() - interval '2 days'),
  ('aa000000-0000-4000-8000-000000000004', '22222222-2222-4222-8222-222222222222', 'activity_recorded', 'Adoration recorded', 'Your adoration session was added to your progress.', '/activities', '{"activityId":"40000000-0000-4000-8000-000000000006"}'::jsonb, null, now() - interval '3 hours')
on conflict (id) do update
set
  user_id = excluded.user_id,
  notification_type = excluded.notification_type,
  title = excluded.title,
  body = excluded.body,
  action_url = excluded.action_url,
  payload = excluded.payload,
  read_at = excluded.read_at,
  created_at = excluded.created_at;

-- ---------------------------------------------------------------------------
-- Competition definitions
-- ---------------------------------------------------------------------------

insert into competition.activity_definitions (
  code,
  name,
  description,
  category,
  requires_duration,
  requires_verification,
  is_repeatable,
  is_active
)
values
  ('ROSARY', 'Pray the Rosary', 'Complete one full rosary.', 'prayer', true, false, true, true),
  ('SCRIPTURE', 'Read Scripture', 'Spend time reading and reflecting on Scripture.', 'scripture', true, false, true, true),
  ('PRAYER', 'Personal Prayer', 'Complete a personal prayer session.', 'prayer', true, false, true, true),
  ('ADORATION', 'Eucharistic Adoration', 'Spend time in Eucharistic adoration.', 'prayer', true, false, true, true),
  ('SERVICE', 'Act of Service', 'Serve a neighbor or the community.', 'service', false, true, true, true),
  ('FASTING', 'Fasting', 'Offer a voluntary fast or sacrifice.', 'sacrifice', true, false, true, true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  requires_duration = excluded.requires_duration,
  requires_verification = excluded.requires_verification,
  is_repeatable = excluded.is_repeatable,
  is_active = excluded.is_active;

insert into competition.level_definitions (
  level_number,
  code,
  name,
  description,
  minimum_total_xp,
  icon_url,
  image_url,
  reward_type,
  is_active
)
values
  (1, 'beginner', 'Beginner', 'Take the first steps in a life of prayer.', 0, '/levels/beginner-icon.png', '/levels/beginner.png', 'title', true),
  (2, 'disciple', 'Disciple', 'Build a steady rhythm of prayer and Scripture.', 250, '/levels/disciple-icon.png', '/levels/disciple.png', 'title', true),
  (3, 'missionary', 'Missionary', 'Put faith into action through service.', 750, '/levels/missionary-icon.png', '/levels/missionary.png', 'title', true),
  (4, 'apostle', 'Apostle', 'Inspire others through faithful witness.', 1500, '/levels/apostle-icon.png', '/levels/apostle.png', 'title', true),
  (5, 'saint_in_training', 'Saint in Training', 'Persevere in heroic daily faithfulness.', 3000, '/levels/saint-icon.png', '/levels/saint.png', 'title', true)
on conflict (level_number) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  minimum_total_xp = excluded.minimum_total_xp,
  icon_url = excluded.icon_url,
  image_url = excluded.image_url,
  reward_type = excluded.reward_type,
  is_active = excluded.is_active;

insert into competition.badge_definitions (
  id,
  code,
  name,
  description,
  category,
  rarity,
  icon_url,
  locked_icon_url,
  requirement_type,
  requirement_value,
  rules,
  points_reward,
  is_repeatable,
  is_shareable,
  is_active
)
values
  ('80000000-0000-4000-8000-000000000001', 'FIRST_ROSARY', 'First Rosary', 'Pray your first complete rosary.', 'prayer', 'common', '/badges/first-rosary.png', '/badges/locked.png', 'activity_count', 1, '{"activityCode":"ROSARY"}'::jsonb, 25, false, true, true),
  ('80000000-0000-4000-8000-000000000002', 'SCRIPTURE_SEEKER', 'Scripture Seeker', 'Complete five Scripture reading sessions.', 'scripture', 'uncommon', '/badges/scripture-seeker.png', '/badges/locked.png', 'activity_count', 5, '{"activityCode":"SCRIPTURE"}'::jsonb, 50, false, true, true),
  ('80000000-0000-4000-8000-000000000003', 'PRAYER_STREAK', 'Prayer Streak', 'Pray on seven consecutive days.', 'discipline', 'rare', '/badges/prayer-streak.png', '/badges/locked.png', 'daily_streak', 7, '{"days":7}'::jsonb, 100, false, true, true),
  ('80000000-0000-4000-8000-000000000004', 'COMMUNITY_HELPER', 'Community Helper', 'Complete three acts of service.', 'service', 'uncommon', '/badges/community-helper.png', '/badges/locked.png', 'activity_count', 3, '{"activityCode":"SERVICE"}'::jsonb, 50, false, true, true)
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  rarity = excluded.rarity,
  icon_url = excluded.icon_url,
  locked_icon_url = excluded.locked_icon_url,
  requirement_type = excluded.requirement_type,
  requirement_value = excluded.requirement_value,
  rules = excluded.rules,
  points_reward = excluded.points_reward,
  is_repeatable = excluded.is_repeatable,
  is_shareable = excluded.is_shareable,
  is_active = excluded.is_active;

insert into competition.point_rules (
  id,
  code,
  activity_code,
  name,
  description,
  points,
  daily_limit,
  weekly_limit,
  effective_from,
  is_active
)
values
  ('30000000-0000-4000-8000-000000000001', 'ROSARY_COMPLETE', 'ROSARY', 'Rosary completed', 'Points for a complete rosary.', 50, 3, 15, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000002', 'SCRIPTURE_SESSION', 'SCRIPTURE', 'Scripture session', 'Points for reading Scripture.', 20, 5, 25, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000003', 'PERSONAL_PRAYER', 'PRAYER', 'Personal prayer', 'Points for personal prayer.', 15, 5, 30, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000004', 'ADORATION_SESSION', 'ADORATION', 'Adoration session', 'Points for Eucharistic adoration.', 40, 2, 8, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000005', 'SERVICE_ACT', 'SERVICE', 'Act of service', 'Points for serving another person.', 60, 3, 12, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000006', 'FASTING_OFFERING', 'FASTING', 'Fasting offering', 'Points for a voluntary fast.', 35, 1, 3, now() - interval '1 year', true)
on conflict (id) do update
set
  code = excluded.code,
  activity_code = excluded.activity_code,
  name = excluded.name,
  description = excluded.description,
  points = excluded.points,
  daily_limit = excluded.daily_limit,
  weekly_limit = excluded.weekly_limit,
  effective_from = excluded.effective_from,
  is_active = excluded.is_active;

insert into competition.challenge_definitions (
  id,
  code,
  title,
  description,
  challenge_type,
  activity_code,
  target_quantity,
  xp_reward,
  badge_reward_id,
  difficulty,
  assignment_weight,
  rules,
  icon_url,
  is_active
)
values
  ('60000000-0000-4000-8000-000000000001', 'DAILY_ROSARY', 'Daily Rosary', 'Pray one complete rosary today.', 'daily', 'ROSARY', 1, 50, '80000000-0000-4000-8000-000000000001', 'normal', 100, '{"reset":"daily"}'::jsonb, '/challenges/rosary.png', true),
  ('60000000-0000-4000-8000-000000000002', 'DAILY_SCRIPTURE', 'Daily Scripture', 'Complete one Scripture reading today.', 'daily', 'SCRIPTURE', 1, 25, null, 'easy', 120, '{"minimumDurationSeconds":300}'::jsonb, '/challenges/scripture.png', true),
  ('60000000-0000-4000-8000-000000000003', 'WEEKLY_SERVICE', 'Serve Your Neighbor', 'Complete three acts of service this week.', 'weekly', 'SERVICE', 3, 150, '80000000-0000-4000-8000-000000000004', 'hard', 60, '{"reset":"weekly"}'::jsonb, '/challenges/service.png', true)
on conflict (id) do update
set
  code = excluded.code,
  title = excluded.title,
  description = excluded.description,
  challenge_type = excluded.challenge_type,
  activity_code = excluded.activity_code,
  target_quantity = excluded.target_quantity,
  xp_reward = excluded.xp_reward,
  badge_reward_id = excluded.badge_reward_id,
  difficulty = excluded.difficulty,
  assignment_weight = excluded.assignment_weight,
  rules = excluded.rules,
  icon_url = excluded.icon_url,
  is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- Competition activity and progress
-- ---------------------------------------------------------------------------

insert into competition.spiritual_activities (
  id,
  user_id,
  activity_code,
  occurred_at,
  completed_at,
  duration_seconds,
  quantity,
  verification_status,
  source,
  city_id,
  country_code,
  idempotency_key,
  metadata
)
values
  ('40000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'ROSARY', now() - interval '2 hours 30 minutes', now() - interval '2 hours', 1800, 1, 'verified', 'manual', 'e0000000-0000-4000-8000-000000000001', 'US', 'seed-test-rosary-1', '{"mysteries":"joyful","note":"Morning rosary"}'::jsonb),
  ('40000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'SCRIPTURE', now() - interval '1 day 25 minutes', now() - interval '1 day', 1500, 2, 'verified', 'challenge', 'e0000000-0000-4000-8000-000000000001', 'US', 'seed-test-scripture-1', '{"passage":"Luke 10:25-37","translation":"NRSVCE"}'::jsonb),
  ('40000000-0000-4000-8000-000000000003', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'PRAYER', now() - interval '2 days 10 minutes', now() - interval '2 days', 600, 1, 'self_reported', 'manual', 'e0000000-0000-4000-8000-000000000001', 'US', 'seed-test-prayer-1', '{"intention":"Peace in the community"}'::jsonb),
  ('40000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'ROSARY', now() - interval '1 hour 25 minutes', now() - interval '1 hour', 1500, 1, 'verified', 'live_prayer', 'e0000000-0000-4000-8000-000000000003', 'MX', 'seed-maria-rosary-1', '{"mysteries":"sorrowful","groupPrayer":true}'::jsonb),
  ('40000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'SERVICE', now() - interval '2 days', now() - interval '2 days', null, 1, 'verified', 'challenge', 'e0000000-0000-4000-8000-000000000003', 'MX', 'seed-maria-service-1', '{"description":"Prepared meals for a parish outreach"}'::jsonb),
  ('40000000-0000-4000-8000-000000000006', '22222222-2222-4222-8222-222222222222', 'ADORATION', now() - interval '3 hours 45 minutes', now() - interval '3 hours', 2700, 1, 'verified', 'manual', 'e0000000-0000-4000-8000-000000000002', 'US', 'seed-john-adoration-1', '{"parish":"St. Joseph"}'::jsonb)
on conflict (id) do update
set
  user_id = excluded.user_id,
  activity_code = excluded.activity_code,
  occurred_at = excluded.occurred_at,
  completed_at = excluded.completed_at,
  duration_seconds = excluded.duration_seconds,
  quantity = excluded.quantity,
  verification_status = excluded.verification_status,
  source = excluded.source,
  city_id = excluded.city_id,
  country_code = excluded.country_code,
  idempotency_key = excluded.idempotency_key,
  metadata = excluded.metadata;

insert into competition.point_ledger (
  id,
  user_id,
  point_rule_id,
  activity_id,
  source_type,
  source_id,
  transaction_type,
  points,
  reason,
  idempotency_key,
  metadata,
  occurred_at
)
values
  ('41000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '30000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'activity', '40000000-0000-4000-8000-000000000001', 'award', 50, 'Completed a rosary', 'seed-ledger-test-rosary', '{}', now() - interval '2 hours'),
  ('41000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '30000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', 'activity', '40000000-0000-4000-8000-000000000002', 'award', 40, 'Read two Scripture passages', 'seed-ledger-test-scripture', '{"multiplier":2}', now() - interval '1 day'),
  ('41000000-0000-4000-8000-000000000003', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '30000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000003', 'activity', '40000000-0000-4000-8000-000000000003', 'award', 15, 'Completed personal prayer', 'seed-ledger-test-prayer', '{}', now() - interval '2 days'),
  ('41000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', '30000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000004', 'activity', '40000000-0000-4000-8000-000000000004', 'award', 50, 'Completed a group rosary', 'seed-ledger-maria-rosary', '{}', now() - interval '1 hour'),
  ('41000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', '30000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000005', 'activity', '40000000-0000-4000-8000-000000000005', 'award', 60, 'Completed an act of service', 'seed-ledger-maria-service', '{}', now() - interval '2 days'),
  ('41000000-0000-4000-8000-000000000006', '22222222-2222-4222-8222-222222222222', '30000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000006', 'activity', '40000000-0000-4000-8000-000000000006', 'award', 40, 'Completed Eucharistic adoration', 'seed-ledger-john-adoration', '{}', now() - interval '3 hours')
on conflict (id) do update
set
  user_id = excluded.user_id,
  point_rule_id = excluded.point_rule_id,
  activity_id = excluded.activity_id,
  source_type = excluded.source_type,
  source_id = excluded.source_id,
  transaction_type = excluded.transaction_type,
  points = excluded.points,
  reason = excluded.reason,
  idempotency_key = excluded.idempotency_key,
  metadata = excluded.metadata,
  occurred_at = excluded.occurred_at;

insert into competition.user_progress (
  user_id,
  total_xp,
  current_level,
  weekly_points,
  yearly_points,
  lifetime_points,
  last_activity_at,
  version
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 350, 2, 120, 840, 1120, now() - interval '2 hours', 8),
  ('11111111-1111-4111-8111-111111111111', 920, 3, 240, 1420, 2050, now() - interval '1 hour', 14),
  ('22222222-2222-4222-8222-222222222222', 180, 1, 75, 460, 610, now() - interval '3 hours', 5)
on conflict (user_id) do update
set
  total_xp = excluded.total_xp,
  current_level = excluded.current_level,
  weekly_points = excluded.weekly_points,
  yearly_points = excluded.yearly_points,
  lifetime_points = excluded.lifetime_points,
  last_activity_at = excluded.last_activity_at,
  version = excluded.version;

insert into competition.user_challenge_assignments (
  id,
  user_id,
  challenge_definition_id,
  assignment_date,
  starts_at,
  expires_at,
  target_quantity,
  current_progress,
  status,
  completed_at,
  reward_claimed_at
)
values
  ('70000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '60000000-0000-4000-8000-000000000001', current_date, date_trunc('day', now()), date_trunc('day', now()) + interval '1 day', 1, 0, 'active', null, null),
  ('70000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '60000000-0000-4000-8000-000000000002', current_date - 1, date_trunc('day', now()) - interval '1 day', date_trunc('day', now()), 1, 1, 'completed', now() - interval '1 day', now() - interval '23 hours'),
  ('70000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '60000000-0000-4000-8000-000000000003', date_trunc('week', current_date)::date, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week', 3, 1, 'active', null, null)
on conflict (id) do update
set
  user_id = excluded.user_id,
  challenge_definition_id = excluded.challenge_definition_id,
  assignment_date = excluded.assignment_date,
  starts_at = excluded.starts_at,
  expires_at = excluded.expires_at,
  target_quantity = excluded.target_quantity,
  current_progress = excluded.current_progress,
  status = excluded.status,
  completed_at = excluded.completed_at,
  reward_claimed_at = excluded.reward_claimed_at;

insert into competition.challenge_progress_events (
  id,
  assignment_id,
  activity_id,
  increment_amount,
  previous_progress,
  resulting_progress,
  idempotency_key,
  occurred_at
)
values
  ('b0000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', 1, 0, 1, 'seed-progress-test-scripture', now() - interval '1 day'),
  ('b0000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000005', 1, 0, 1, 'seed-progress-maria-service', now() - interval '2 days')
on conflict (id) do update
set
  assignment_id = excluded.assignment_id,
  activity_id = excluded.activity_id,
  increment_amount = excluded.increment_amount,
  previous_progress = excluded.previous_progress,
  resulting_progress = excluded.resulting_progress,
  idempotency_key = excluded.idempotency_key,
  occurred_at = excluded.occurred_at;

-- ---------------------------------------------------------------------------
-- Badges and sharing
-- ---------------------------------------------------------------------------

insert into competition.user_badges (
  id,
  user_id,
  badge_id,
  earned_at,
  source_type,
  source_id,
  sequence_number,
  is_featured,
  metadata
)
values
  ('90000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '80000000-0000-4000-8000-000000000001', now() - interval '2 hours', 'activity', '40000000-0000-4000-8000-000000000001', 1, true, '{"celebrated":true}'::jsonb),
  ('90000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', '80000000-0000-4000-8000-000000000001', now() - interval '45 days', 'activity', '40000000-0000-4000-8000-000000000004', 1, true, '{}'),
  ('90000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '80000000-0000-4000-8000-000000000004', now() - interval '10 days', 'challenge', '60000000-0000-4000-8000-000000000003', 1, false, '{"serviceActs":3}'::jsonb)
on conflict (id) do update
set
  user_id = excluded.user_id,
  badge_id = excluded.badge_id,
  earned_at = excluded.earned_at,
  source_type = excluded.source_type,
  source_id = excluded.source_id,
  sequence_number = excluded.sequence_number,
  is_featured = excluded.is_featured,
  metadata = excluded.metadata;

insert into competition.user_badge_progress (
  user_id,
  badge_id,
  current_value,
  required_value
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '80000000-0000-4000-8000-000000000002', 2, 5),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '80000000-0000-4000-8000-000000000003', 3, 7),
  ('11111111-1111-4111-8111-111111111111', '80000000-0000-4000-8000-000000000002', 4, 5),
  ('22222222-2222-4222-8222-222222222222', '80000000-0000-4000-8000-000000000004', 1, 3)
on conflict (user_id, badge_id) do update
set
  current_value = excluded.current_value,
  required_value = excluded.required_value;

insert into competition.badge_shares (
  id,
  user_badge_id,
  share_token,
  platform,
  visibility,
  expires_at
)
values
  ('a0000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001', 'seed-first-rosary-test', 'copy_link', 'public', now() + interval '90 days'),
  ('a0000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000002', 'seed-first-rosary-maria', 'whatsapp', 'unlisted', now() + interval '90 days')
on conflict (id) do update
set
  user_badge_id = excluded.user_badge_id,
  share_token = excluded.share_token,
  platform = excluded.platform,
  visibility = excluded.visibility,
  expires_at = excluded.expires_at,
  revoked_at = null;

-- ---------------------------------------------------------------------------
-- Leaderboards and metric snapshots
-- ---------------------------------------------------------------------------

insert into competition.leaderboard_periods (
  id,
  period_type,
  code,
  name,
  starts_at,
  ends_at,
  status,
  finalized_at
)
values
  ('50000000-0000-4000-8000-000000000001', 'weekly', 'seed-current-week', 'Current Week', date_trunc('week', now()), date_trunc('week', now()) + interval '1 week', 'active', null),
  ('50000000-0000-4000-8000-000000000002', 'weekly', 'seed-previous-week', 'Previous Week', date_trunc('week', now()) - interval '1 week', date_trunc('week', now()), 'finalized', date_trunc('week', now()) + interval '1 hour')
on conflict (id) do update
set
  period_type = excluded.period_type,
  code = excluded.code,
  name = excluded.name,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  status = excluded.status,
  finalized_at = excluded.finalized_at;

insert into competition.leaderboard_entries (
  period_id,
  user_id,
  scope_type,
  scope_reference,
  points,
  rank,
  rosaries_count,
  scripture_readings_count,
  prayers_count
)
values
  ('50000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'global', 'global', 240, 1, 3, 4, 9),
  ('50000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'global', 'global', 120, 2, 1, 2, 5),
  ('50000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'global', 'global', 75, 3, 0, 3, 4),
  ('50000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'country', 'US', 120, 1, 1, 2, 5),
  ('50000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'country', 'US', 75, 2, 0, 3, 4),
  ('50000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'country', 'MX', 240, 1, 3, 4, 9),
  ('50000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'global', 'global', 410, 1, 5, 6, 14),
  ('50000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'global', 'global', 280, 2, 3, 5, 11),
  ('50000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', 'global', 'global', 190, 3, 2, 4, 8)
on conflict (period_id, user_id, scope_type, scope_reference) do update
set
  points = excluded.points,
  rank = excluded.rank,
  rosaries_count = excluded.rosaries_count,
  scripture_readings_count = excluded.scripture_readings_count,
  prayers_count = excluded.prayers_count;

insert into competition.user_metric_snapshots (
  user_id,
  snapshot_date,
  rosaries_count,
  scripture_readings_count,
  prayer_sessions_count,
  service_acts_count,
  points_earned,
  prayer_duration_seconds
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', current_date, 1, 0, 1, 0, 50, 1800),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', current_date - 1, 0, 2, 1, 0, 40, 1500),
  ('11111111-1111-4111-8111-111111111111', current_date, 1, 0, 1, 0, 50, 1500),
  ('22222222-2222-4222-8222-222222222222', current_date, 0, 0, 1, 0, 40, 2700)
on conflict (user_id, snapshot_date) do update
set
  rosaries_count = excluded.rosaries_count,
  scripture_readings_count = excluded.scripture_readings_count,
  prayer_sessions_count = excluded.prayer_sessions_count,
  service_acts_count = excluded.service_acts_count,
  points_earned = excluded.points_earned,
  prayer_duration_seconds = excluded.prayer_duration_seconds;

-- ---------------------------------------------------------------------------
-- Prayer events and privacy-safe aggregates
-- ---------------------------------------------------------------------------

insert into prayer.prayer_events (
  id,
  user_id,
  activity_id,
  prayer_type,
  quantity,
  started_at,
  completed_at,
  city_id,
  country_code,
  visibility,
  metadata
)
values
  ('f0000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '40000000-0000-4000-8000-000000000001', 'rosary', 1, now() - interval '2 hours 30 minutes', now() - interval '2 hours', 'e0000000-0000-4000-8000-000000000001', 'US', 'aggregated', '{"mysteries":"joyful"}'::jsonb),
  ('f0000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '40000000-0000-4000-8000-000000000003', 'intercession', 1, now() - interval '2 days 10 minutes', now() - interval '2 days', 'e0000000-0000-4000-8000-000000000001', 'US', 'aggregated', '{"intentionCategory":"community"}'::jsonb),
  ('f0000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '40000000-0000-4000-8000-000000000004', 'rosary', 1, now() - interval '1 hour 25 minutes', now() - interval '1 hour', 'e0000000-0000-4000-8000-000000000003', 'MX', 'aggregated', '{"groupPrayer":true}'::jsonb),
  ('f0000000-0000-4000-8000-000000000004', '22222222-2222-4222-8222-222222222222', '40000000-0000-4000-8000-000000000006', 'adoration', 1, now() - interval '3 hours 45 minutes', now() - interval '3 hours', 'e0000000-0000-4000-8000-000000000002', 'US', 'private', '{}')
on conflict (id) do update
set
  user_id = excluded.user_id,
  activity_id = excluded.activity_id,
  prayer_type = excluded.prayer_type,
  quantity = excluded.quantity,
  started_at = excluded.started_at,
  completed_at = excluded.completed_at,
  city_id = excluded.city_id,
  country_code = excluded.country_code,
  visibility = excluded.visibility,
  metadata = excluded.metadata;

insert into prayer.city_daily_aggregates (
  city_id,
  aggregate_date,
  total_prayers,
  unique_users,
  rosaries,
  prayer_duration_seconds
)
values
  ('e0000000-0000-4000-8000-000000000001', current_date, 38, 12, 9, 32400),
  ('e0000000-0000-4000-8000-000000000002', current_date, 24, 8, 5, 21600),
  ('e0000000-0000-4000-8000-000000000003', current_date, 47, 16, 12, 43800),
  ('e0000000-0000-4000-8000-000000000004', current_date, 19, 7, 4, 17100)
on conflict (city_id, aggregate_date) do update
set
  total_prayers = excluded.total_prayers,
  unique_users = excluded.unique_users,
  rosaries = excluded.rosaries,
  prayer_duration_seconds = excluded.prayer_duration_seconds;

insert into prayer.country_daily_aggregates (
  country_code,
  aggregate_date,
  total_prayers,
  unique_users,
  rosaries,
  prayer_duration_seconds
)
values
  ('US', current_date, 1250, 380, 295, 1125000),
  ('MX', current_date, 980, 315, 248, 882000),
  ('VA', current_date, 84, 24, 18, 75600)
on conflict (country_code, aggregate_date) do update
set
  total_prayers = excluded.total_prayers,
  unique_users = excluded.unique_users,
  rosaries = excluded.rosaries,
  prayer_duration_seconds = excluded.prayer_duration_seconds;

insert into prayer.map_markers (
  id,
  aggregation_level,
  location_reference,
  name,
  country_code,
  latitude,
  longitude,
  prayer_count,
  unique_users,
  intensity,
  period_start,
  period_end
)
values
  ('51000000-0000-4000-8000-000000000001', 'country', 'US', 'United States', 'US', 39.828300, -98.579500, 8750, 1820, 0.9200, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week'),
  ('51000000-0000-4000-8000-000000000002', 'country', 'MX', 'Mexico', 'MX', 23.634500, -102.552800, 6860, 1430, 0.7800, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week'),
  ('51000000-0000-4000-8000-000000000003', 'country', 'VA', 'Vatican City', 'VA', 41.902900, 12.453400, 590, 112, 0.4100, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week'),
  ('51000000-0000-4000-8000-000000000004', 'city', 'e0000000-0000-4000-8000-000000000001', 'Austin', 'US', 30.267200, -97.743100, 266, 74, 0.7100, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week'),
  ('51000000-0000-4000-8000-000000000005', 'city', 'e0000000-0000-4000-8000-000000000002', 'Dallas', 'US', 32.776700, -96.797000, 184, 53, 0.5900, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week'),
  ('51000000-0000-4000-8000-000000000006', 'city', 'e0000000-0000-4000-8000-000000000003', 'Mexico City', 'MX', 19.432600, -99.133200, 329, 91, 0.8400, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week'),
  ('51000000-0000-4000-8000-000000000007', 'city', 'e0000000-0000-4000-8000-000000000004', 'Vatican City', 'VA', 41.902900, 12.453400, 132, 34, 0.4800, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week')
on conflict (id) do update
set
  aggregation_level = excluded.aggregation_level,
  location_reference = excluded.location_reference,
  name = excluded.name,
  country_code = excluded.country_code,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  prayer_count = excluded.prayer_count,
  unique_users = excluded.unique_users,
  intensity = excluded.intensity,
  period_start = excluded.period_start,
  period_end = excluded.period_end;

-- ---------------------------------------------------------------------------
-- Platform reliability data
-- ---------------------------------------------------------------------------

insert into platform.idempotency_records (
  id,
  user_id,
  idempotency_key,
  request_method,
  request_path,
  request_hash,
  response_status,
  response_body,
  completed_at,
  expires_at
)
values
  ('c0000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'seed-api-activity-request', 'POST', '/api/v1/activities', '5cbb9b1f9d617109a10e82d16a238a173b0e8a9444cc80e8918a79c8b5607360', 201, '{"data":{"id":"40000000-0000-4000-8000-000000000001"}}'::jsonb, now() - interval '2 hours', now() + interval '7 days'),
  ('c0000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'seed-api-claim-request', 'POST', '/api/v1/challenges/70000000-0000-4000-8000-000000000003/claim', 'bb157861a164e35ec44537f7e1f79e4226aea619a9f80f6d8bc4160035716e40', 409, '{"error":{"code":"challenge_incomplete","message":"Challenge is not complete."}}'::jsonb, now() - interval '30 minutes', now() + interval '7 days')
on conflict (id) do update
set
  user_id = excluded.user_id,
  idempotency_key = excluded.idempotency_key,
  request_method = excluded.request_method,
  request_path = excluded.request_path,
  request_hash = excluded.request_hash,
  response_status = excluded.response_status,
  response_body = excluded.response_body,
  completed_at = excluded.completed_at,
  expires_at = excluded.expires_at;

insert into platform.outbox_events (
  id,
  aggregate_type,
  aggregate_id,
  event_type,
  payload,
  occurred_at,
  processing_status,
  attempt_count,
  available_at,
  processed_at,
  last_error
)
values
  ('d0000000-0000-4000-8000-000000000001', 'spiritual_activity', '40000000-0000-4000-8000-000000000001', 'spiritual_activity.recorded', '{"userId":"9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002","activityCode":"ROSARY","quantity":1}'::jsonb, now() - interval '2 hours', 'processed', 1, now() - interval '2 hours', now() - interval '1 hour 59 minutes', null),
  ('d0000000-0000-4000-8000-000000000002', 'user_badge', '90000000-0000-4000-8000-000000000001', 'badge.earned', '{"userId":"9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002","badgeCode":"FIRST_ROSARY"}'::jsonb, now() - interval '2 hours', 'pending', 0, now() - interval '2 hours', null, null),
  ('d0000000-0000-4000-8000-000000000003', 'challenge_assignment', '70000000-0000-4000-8000-000000000002', 'challenge.completed', '{"userId":"9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002","xpReward":25}'::jsonb, now() - interval '1 day', 'failed', 3, now() - interval '23 hours', null, 'Seeded retry example')
on conflict (id) do update
set
  aggregate_type = excluded.aggregate_type,
  aggregate_id = excluded.aggregate_id,
  event_type = excluded.event_type,
  payload = excluded.payload,
  occurred_at = excluded.occurred_at,
  processing_status = excluded.processing_status,
  attempt_count = excluded.attempt_count,
  available_at = excluded.available_at,
  processed_at = excluded.processed_at,
  last_error = excluded.last_error;

-- Keep the seed honest as the schema evolves. A newly added application table
-- must receive seed data before a reset can succeed.
do $$
declare
  table_record record;
  has_rows boolean;
begin
  for table_record in
    select table_schema, table_name
    from information_schema.tables
    where table_type = 'BASE TABLE'
      and table_schema in ('app', 'competition', 'prayer', 'platform')
    order by table_schema, table_name
  loop
    execute format(
      'select exists (select 1 from %I.%I)',
      table_record.table_schema,
      table_record.table_name
    ) into has_rows;

    if not has_rows then
      raise exception 'Seed data is missing for %.%', table_record.table_schema, table_record.table_name;
    end if;
  end loop;
end
$$;

commit;
