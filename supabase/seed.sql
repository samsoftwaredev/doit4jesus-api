-- Local development seed data for every application-owned table.
--
-- Login credentials (all passwords are 12345678):
--   test@test.com
--   test@admin.com (admin)
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
    '33333333-3333-4333-8333-333333333333',
    'authenticated',
    'authenticated',
    'test@admin.com',
    crypt('12345678', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Test Administrator"}'::jsonb,
    now() - interval '14 days',
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
    '33333333-3333-4333-8333-333333333333',
    '33333333-3333-4333-8333-333333333333',
    '33333333-3333-4333-8333-333333333333',
    '{"sub":"33333333-3333-4333-8333-333333333333","email":"test@admin.com","email_verified":true,"phone_verified":false}'::jsonb,
    'email',
    now(),
    now() - interval '14 days',
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
  ('33333333-3333-4333-8333-333333333333', 'test@admin.com', 'active', now() - interval '14 days', now() - interval '30 minutes', now() - interval '14 days'),
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
  gender,
  preferred_language,
  timezone,
  city_id,
  country_code,
  leaderboard_visibility,
  prayer_map_visibility
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'Test User', 'testuser', 'https://i.pravatar.cc/256?u=testuser', 'Faithful Beginner', 'male', 'en', 'America/Chicago', 'e0000000-0000-4000-8000-000000000001', 'US', 'public', 'aggregated'),
  ('33333333-3333-4333-8333-333333333333', 'Test Administrator', 'testadmin', 'https://i.pravatar.cc/256?u=testadmin', 'Administrator', 'male', 'en', 'America/Chicago', 'e0000000-0000-4000-8000-000000000001', 'US', 'public', 'aggregated'),
  ('11111111-1111-4111-8111-111111111111', 'Maria Santos', 'mariasantos', 'https://i.pravatar.cc/256?u=mariasantos', 'Prayer Champion', 'female', 'es', 'America/Mexico_City', 'e0000000-0000-4000-8000-000000000003', 'MX', 'public', 'aggregated'),
  ('22222222-2222-4222-8222-222222222222', 'John Paul', 'johnpaul', 'https://i.pravatar.cc/256?u=johnpaul', 'Scripture Seeker', 'male', 'en', 'America/Chicago', 'e0000000-0000-4000-8000-000000000002', 'US', 'public', 'aggregated')
on conflict (user_id) do update
set
  display_name = excluded.display_name,
  username = excluded.username,
  avatar_url = excluded.avatar_url,
  title = excluded.title,
  gender = excluded.gender,
  preferred_language = excluded.preferred_language,
  timezone = excluded.timezone,
  city_id = excluded.city_id,
  country_code = excluded.country_code,
  leaderboard_visibility = excluded.leaderboard_visibility,
  prayer_map_visibility = excluded.prayer_map_visibility;

-- ---------------------------------------------------------------------------
-- Prayer intention moderation examples
-- ---------------------------------------------------------------------------

insert into prayer.prayer_intentions (
  id,
  creator_id,
  title,
  description,
  symbol,
  status,
  reviewed_by,
  reviewed_at,
  expires_at,
  created_at
)
values
  (
    'd9000000-0000-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'Praying for my brother',
    'He is currently having back pain.',
    'candle',
    'visible',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    now() - interval '3 days',
    now() + interval '27 days',
    now() - interval '3 days'
  ),
  (
    'd9000000-0000-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'Praying for my family',
    'Please pray for patience and peace at home.',
    'dove',
    'pending',
    null,
    null,
    null,
    now() - interval '1 day'
  ),
  (
    'd9000000-0000-4000-8000-000000000003',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    'Praying for healing',
    'Please pray for healing and strength during recovery.',
    'cross',
    'rejected',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    now() - interval '2 days',
    now() + interval '28 days',
    now() - interval '2 days'
  )
on conflict (id) do update
set
  creator_id = excluded.creator_id,
  title = excluded.title,
  description = excluded.description,
  symbol = excluded.symbol,
  status = excluded.status,
  reviewed_by = excluded.reviewed_by,
  reviewed_at = excluded.reviewed_at,
  expires_at = excluded.expires_at,
  created_at = excluded.created_at;

insert into prayer.prayer_intention_approval_counts (
  user_id,
  approved_count,
  updated_at
)
values (
  '11111111-1111-4111-8111-111111111111',
  1,
  now() - interval '3 days'
)
on conflict (user_id) do update
set
  approved_count = excluded.approved_count,
  updated_at = excluded.updated_at;

insert into prayer.prayer_intention_prayers (
  id,
  intention_id,
  user_id,
  created_at
)
values
  (
    'd9100000-0000-4000-8000-000000000001',
    'd9000000-0000-4000-8000-000000000001',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    now() - interval '2 days'
  ),
  (
    'd9100000-0000-4000-8000-000000000002',
    'd9000000-0000-4000-8000-000000000001',
    '22222222-2222-4222-8222-222222222222',
    now() - interval '1 day'
  )
on conflict (id) do update
set
  intention_id = excluded.intention_id,
  user_id = excluded.user_id,
  created_at = excluded.created_at;

-- ---------------------------------------------------------------------------
-- Friendships and request examples
-- ---------------------------------------------------------------------------

insert into app.friendships (id, user_low_id, user_high_id)
values (
  'fb000000-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'
)
on conflict (user_low_id, user_high_id) do update
set created_at = excluded.created_at;

insert into app.friend_requests (
  id,
  requester_id,
  recipient_id,
  status,
  responded_at,
  cancelled_at
)
values
  (
    'fb000000-0000-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    'pending',
    null,
    null
  ),
  (
    'fb000000-0000-4000-8000-000000000003',
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    '22222222-2222-4222-8222-222222222222',
    'rejected',
    now() - interval '4 days',
    null
  )
on conflict (id) do update
set
  requester_id = excluded.requester_id,
  recipient_id = excluded.recipient_id,
  status = excluded.status,
  responded_at = excluded.responded_at,
  cancelled_at = excluded.cancelled_at;

-- ---------------------------------------------------------------------------
-- Church directory, personal links, and moderation examples
-- ---------------------------------------------------------------------------

insert into app.user_roles (user_id, role)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'admin'),
  ('33333333-3333-4333-8333-333333333333', 'admin')
on conflict (user_id) do update
set role = excluded.role;

insert into app.dioceses (id, country_code, name)
values
  ('c5000000-0000-4000-8000-000000000001', 'US', 'Diocese of Austin'),
  ('c5000000-0000-4000-8000-000000000002', 'US', 'Diocese of Dallas'),
  ('c5000000-0000-4000-8000-000000000003', 'MX', 'Archdiocese of Mexico City')
on conflict (id) do update
set
  country_code = excluded.country_code,
  name = excluded.name;

insert into app.churches (
  id,
  diocese_id,
  name,
  address_line_1,
  address_line_2,
  city,
  region_name,
  postal_code,
  country_code,
  timezone,
  latitude,
  longitude,
  is_active
)
values
  ('c6000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', 'St. Mary Cathedral', '203 E 10th St', null, 'Austin', 'Texas', '78701', 'US', 'America/Chicago', 30.270833, -97.741389, true),
  ('c6000000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 'St. Thomas More Catholic Church', '10205 FM 620 N', null, 'Austin', 'Texas', '78726', 'US', 'America/Chicago', 30.419492, -97.845792, true),
  ('c6000000-0000-4000-8000-000000000003', 'c5000000-0000-4000-8000-000000000002', 'Cathedral Shrine of the Virgin of Guadalupe', '2215 Ross Ave', null, 'Dallas', 'Texas', '75201', 'US', 'America/Chicago', 32.784231, -96.792618, true),
  ('c6000000-0000-4000-8000-000000000004', 'c5000000-0000-4000-8000-000000000003', 'Mexico City Metropolitan Cathedral', 'Plaza de la Constitución S/N', null, 'Mexico City', 'Mexico City', '06000', 'MX', 'America/Mexico_City', 19.434167, -99.133056, true)
on conflict (id) do update
set
  diocese_id = excluded.diocese_id,
  name = excluded.name,
  address_line_1 = excluded.address_line_1,
  address_line_2 = excluded.address_line_2,
  city = excluded.city,
  region_name = excluded.region_name,
  postal_code = excluded.postal_code,
  country_code = excluded.country_code,
  timezone = excluded.timezone,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  is_active = excluded.is_active;

insert into app.church_service_times (
  id,
  church_id,
  service_type,
  weekday,
  starts_at,
  ends_at
)
values
  ('c7000000-0000-4000-8000-000000000001', 'c6000000-0000-4000-8000-000000000001', 'mass', 0, '08:00', null),
  ('c7000000-0000-4000-8000-000000000002', 'c6000000-0000-4000-8000-000000000001', 'mass', 0, '10:00', '11:15'),
  ('c7000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 'confession', 6, '16:00', '17:00'),
  ('c7000000-0000-4000-8000-000000000004', 'c6000000-0000-4000-8000-000000000001', 'adoration', 3, '18:00', '20:00'),
  ('c7000000-0000-4000-8000-000000000005', 'c6000000-0000-4000-8000-000000000002', 'mass', 0, '09:00', null),
  ('c7000000-0000-4000-8000-000000000006', 'c6000000-0000-4000-8000-000000000002', 'confession', 2, '17:30', '18:30'),
  ('c7000000-0000-4000-8000-000000000007', 'c6000000-0000-4000-8000-000000000003', 'mass', 0, '12:00', null),
  ('c7000000-0000-4000-8000-000000000008', 'c6000000-0000-4000-8000-000000000004', 'mass', 0, '09:00', null)
on conflict (id) do update
set
  church_id = excluded.church_id,
  service_type = excluded.service_type,
  weekday = excluded.weekday,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at;

-- Reset the seeded users' primary flags before the upsert below so rerunning
-- this seed remains valid even after exercising the primary-church endpoint.
update app.user_churches
set is_primary = false
where user_id in (
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid
);

insert into app.user_churches (user_id, church_id, is_primary)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'c6000000-0000-4000-8000-000000000001', true),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'c6000000-0000-4000-8000-000000000002', false),
  ('11111111-1111-4111-8111-111111111111', 'c6000000-0000-4000-8000-000000000004', true)
on conflict (user_id, church_id) do update
set is_primary = excluded.is_primary;

insert into app.church_change_requests (
  id,
  submitted_by,
  request_type,
  church_id,
  proposed_church,
  proposed_service_times,
  notes,
  status
)
values (
  'c8000000-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111',
  'schedule_update',
  'c6000000-0000-4000-8000-000000000004',
  '{}'::jsonb,
  '[
    {"service_type":"mass","weekday":0,"start_time":"08:00","end_time":null},
    {"service_type":"mass","weekday":0,"start_time":"12:00","end_time":null},
    {"service_type":"adoration","weekday":4,"start_time":"18:00","end_time":"20:00"}
  ]'::jsonb,
  'Please add the current Sunday Mass and Friday adoration times.',
  'pending'
)
on conflict (id) do update
set
  submitted_by = excluded.submitted_by,
  request_type = excluded.request_type,
  church_id = excluded.church_id,
  proposed_church = excluded.proposed_church,
  proposed_service_times = excluded.proposed_service_times,
  notes = excluded.notes,
  status = excluded.status,
  reviewed_by = null,
  reviewed_at = null,
  rejection_reason = null;

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
  ('aa000000-0000-4000-8000-000000000004', '22222222-2222-4222-8222-222222222222', 'activity_recorded', 'Adoration recorded', 'Your adoration session was added to your progress.', '/activities', '{"activityId":"40000000-0000-4000-8000-000000000006"}'::jsonb, null, now() - interval '3 hours'),
  ('aa000000-0000-4000-8000-000000000005', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'friend_request_received', 'New friend request', 'John Paul sent you a friend request.', '/friends/requests', '{"friendRequestId":"fb000000-0000-4000-8000-000000000002","requesterId":"22222222-2222-4222-8222-222222222222"}'::jsonb, null, now() - interval '30 minutes')
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
  ('FASTING', 'Fasting', 'Offer a voluntary fast or sacrifice.', 'sacrifice', true, false, true, true),
  ('HONESTY_REFLECTION', 'Honesty Reflection', 'Reflect honestly on one choice and its impact.', 'discipline', false, false, true, true),
  ('TRUST_ACT', 'Act of Trust', 'Record a concrete act of trust during difficulty.', 'discipline', false, false, true, true),
  ('RULE_OF_LIFE', 'Rule of Life', 'Complete the daily commitments in your rule of life.', 'discipline', false, false, true, true)
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
  (1, 'awakened', 'Awakened', 'Begins recognizing the battle.', 0, '/levels/awakened-icon.png', '/levels/awakened.png', 'title', true),
  (2, 'seeker', 'Seeker', 'Starts building daily habits.', 250, '/levels/seeker-icon.png', '/levels/seeker.png', 'title', true),
  (3, 'disciple', 'Disciple', 'Follows a consistent rule of life.', 750, '/levels/disciple-icon.png', '/levels/disciple.png', 'title', true),
  (4, 'fighter', 'Fighter', 'Resists recurring temptations.', 1500, '/levels/fighter-icon.png', '/levels/fighter.png', 'title', true),
  (5, 'guardian', 'Guardian', 'Protects his environment and relationships.', 3000, '/levels/guardian-icon.png', '/levels/guardian.png', 'title', true),
  (6, 'servant', 'Servant', 'Regularly serves others.', 5000, '/levels/servant-icon.png', '/levels/servant.png', 'title', true),
  (7, 'brother', 'Brother', 'Supports other men.', 7500, '/levels/brother-icon.png', '/levels/brother.png', 'title', true),
  (8, 'leader', 'Leader', 'Leads by example.', 11000, '/levels/leader-icon.png', '/levels/leader.png', 'title', true),
  (9, 'witness', 'Witness', 'Lives the faith publicly and consistently.', 16000, '/levels/witness-icon.png', '/levels/witness.png', 'title', true),
  (10, 'persevering_disciple', 'Persevering Disciple', 'Continues faithfully over time.', 22000, '/levels/persevering-disciple-icon.png', '/levels/persevering-disciple.png', 'title', true)
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
  ('80000000-0000-4000-8000-000000000004', 'COMMUNITY_HELPER', 'Community Helper', 'Complete three acts of service.', 'service', 'uncommon', '/badges/community-helper.png', '/badges/locked.png', 'activity_count', 3, '{"activityCode":"SERVICE"}'::jsonb, 50, false, true, true),
  ('80000000-0000-4000-8000-000000000005', 'BELT_OF_TRUTH', 'Belt of Truth', 'Wear the Belt of Truth by practicing honesty and integrity each day.', 'discipline', 'uncommon', '/badges/belt-of-truth.png', '/badges/locked.png', 'daily_streak', 7, '{"virtue":"truth","requirements":[{"type":"daily_honesty_reflection","value":7}]}'::jsonb, 75, false, true, true),
  ('80000000-0000-4000-8000-000000000006', 'SHIELD_OF_FAITH', 'Shield of Faith', 'Unlock the Shield of Faith through sustained prayer, Scripture, and trust during difficulty.', 'prayer', 'rare', '/badges/shield-of-faith.png', '/badges/locked.png', 'all_requirements', 3, '{"virtue":"faith","requirements":[{"type":"prayer_days","value":7,"description":"Seven days of prayer"},{"type":"scripture_plan_completed","value":1,"description":"One completed Scripture plan"},{"type":"trust_act_during_difficulty","value":1,"description":"One act of trust during difficulty"}]}'::jsonb, 150, false, true, true),
  ('80000000-0000-4000-8000-000000000007', 'SWORD_OF_THE_SPIRIT', 'Sword of the Spirit', 'Unlock the Sword of the Spirit by storing God’s word in your heart.', 'scripture', 'rare', '/badges/sword-of-the-spirit.png', '/badges/locked.png', 'activity_count', 10, '{"virtue":"wisdom","requirements":[{"type":"scripture_reading_sessions","value":10}]}'::jsonb, 125, false, true, true),
  ('80000000-0000-4000-8000-000000000008', 'HELMET_OF_SALVATION', 'Helmet of Salvation', 'Unlock the Helmet of Salvation by renewing hope and guarding your mind.', 'discipline', 'rare', '/badges/helmet-of-salvation.png', '/badges/locked.png', 'daily_streak', 14, '{"virtue":"hope","requirements":[{"type":"daily_prayer_streak","value":14}]}'::jsonb, 125, false, true, true),
  ('80000000-0000-4000-8000-000000000009', 'BOOTS_OF_READINESS', 'Boots of Readiness', 'Unlock the Boots of Readiness by being ready to serve and bring peace.', 'service', 'uncommon', '/badges/boots-of-readiness.png', '/badges/locked.png', 'activity_count', 5, '{"virtue":"readiness","requirements":[{"type":"service_acts","value":5}]}'::jsonb, 100, false, true, true),
  ('80000000-0000-4000-8000-000000000010', 'BREASTPLATE_OF_RIGHTEOUSNESS', 'Breastplate of Righteousness', 'Unlock the Breastplate of Righteousness through consistent righteous choices.', 'discipline', 'epic', '/badges/breastplate-of-righteousness.png', '/badges/locked.png', 'daily_streak', 21, '{"virtue":"righteousness","requirements":[{"type":"daily_rule_of_life_streak","value":21}]}'::jsonb, 200, false, true, true),
  ('80000000-0000-4000-8000-000000000011', 'CHURCH_SCHEDULE_STEWARD', 'Church Schedule Steward', 'Keep a church''s worship schedule current. Earned for every approved schedule update.', 'community', 'common', '/badges/community-helper.png', '/badges/locked.png', 'approved_church_schedule_update', 1, '{"requestType":"schedule_update"}'::jsonb, 0, true, true, true)
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

-- ---------------------------------------------------------------------------
-- Fictional spiritual-battle game configuration
-- ---------------------------------------------------------------------------

insert into competition.game_balance_config (
  id,
  schema_version,
  virtue_min,
  virtue_max,
  default_virtue_value,
  demon_default_max_hp,
  attack_penalty_min,
  attack_penalty_max,
  challenge_reward_min,
  challenge_reward_max,
  rules
)
values (
  true,
  '1.0.0',
  0,
  100,
  50,
  100,
  2,
  8,
  3,
  10,
  jsonb_build_array(
    'The server calculates all virtue changes, demon damage, XP, and rewards.',
    'Virtues cannot drop below 0 or rise above 100.',
    'A missed challenge should create only a small, recoverable penalty.',
    'A completed defense increases the associated virtue and damages the demon.',
    'Defeating a demon grants a final bonus to its primary counter-virtue.',
    'Saints are thematic mentors and examples, not magical power-ups.'
  )
)
on conflict (id) do update
set
  schema_version = excluded.schema_version,
  virtue_min = excluded.virtue_min,
  virtue_max = excluded.virtue_max,
  default_virtue_value = excluded.default_virtue_value,
  demon_default_max_hp = excluded.demon_default_max_hp,
  attack_penalty_min = excluded.attack_penalty_min,
  attack_penalty_max = excluded.attack_penalty_max,
  challenge_reward_min = excluded.challenge_reward_min,
  challenge_reward_max = excluded.challenge_reward_max,
  rules = excluded.rules;

insert into competition.virtue_definitions (
  code,
  name,
  description,
  default_value,
  icon,
  is_active
)
values
  ('FAITH', 'Faith', 'Trust in God and willingness to remain close to Him.', 50, 'shield-cross', true),
  ('DISCIPLINE', 'Discipline', 'Choosing the good even when motivation is low.', 50, 'belt', true),
  ('COURAGE', 'Courage', 'Facing fear, discomfort, responsibility, and difficult truth.', 50, 'sword', true),
  ('WISDOM', 'Wisdom', 'Recognizing truth and choosing the next good action.', 50, 'open-book', true),
  ('CHARITY', 'Charity', 'Loving others through patience, mercy, service, and truth.', 50, 'sacred-heart', true),
  ('PURITY', 'Purity', 'Seeing people with dignity and guarding the heart and imagination.', 50, 'lily-shield', true),
  ('PERSEVERANCE', 'Perseverance', 'Returning and continuing after difficulty or failure.', 50, 'boots', true),
  ('HUMILITY', 'Humility', 'Living truthfully without self-exaltation or self-contempt.', 50, 'kneeling-knight', true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  default_value = excluded.default_value,
  icon = excluded.icon,
  is_active = excluded.is_active;

insert into competition.saint_definitions (id, code, name, description, is_active)
values
  ('a1000000-0000-4000-8000-000000000001', 'IGNATIUS_OF_LOYOLA', 'St. Ignatius of Loyola', 'A mentor of discernment and ordered attention.', true),
  ('a1000000-0000-4000-8000-000000000002', 'JOSEPH', 'St. Joseph', 'A mentor of steady work, responsibility, and quiet service.', true),
  ('a1000000-0000-4000-8000-000000000003', 'FRANCIS_DE_SALES', 'St. Francis de Sales', 'A mentor of gentleness and patient speech.', true),
  ('a1000000-0000-4000-8000-000000000004', 'THERESE_OF_LISIEUX', 'St. Thérèse of Lisieux', 'A mentor of hidden love and the little way.', true),
  ('a1000000-0000-4000-8000-000000000005', 'BENEDICT', 'St. Benedict of Nursia', 'A mentor of prayerful work, stability, and holy order.', true),
  ('a1000000-0000-4000-8000-000000000006', 'FRANCIS_OF_ASSISI', 'St. Francis of Assisi', 'A mentor of gratitude, simplicity, and joy in the good of others.', true),
  ('a1000000-0000-4000-8000-000000000007', 'JOAN_OF_ARC', 'St. Joan of Arc', 'A mentor of courageous obedience despite fear.', true),
  ('a1000000-0000-4000-8000-000000000008', 'PETER', 'St. Peter', 'A mentor of repentance and returning after failure.', true),
  ('a1000000-0000-4000-8000-000000000009', 'PHILIP_NERI', 'St. Philip Neri', 'A mentor of joyful charity and practical wisdom.', true),
  ('a1000000-0000-4000-8000-000000000010', 'LAWRENCE', 'St. Lawrence', 'A mentor of generosity and love of people over possessions.', true),
  ('a1000000-0000-4000-8000-000000000011', 'MARIA_GORETTI', 'St. Maria Goretti', 'A mentor of purity, dignity, forgiveness, and courage.', true),
  ('a1000000-0000-4000-8000-000000000012', 'BLESSED_VIRGIN_MARY', 'Blessed Virgin Mary', 'A motherly mentor of faith, humility, and steadfast hope.', true),
  ('a1000000-0000-4000-8000-000000000013', 'OUR_LADY_QUEEN_OF_HEAVEN', 'Our Lady, Queen of Heaven', 'A mentor of prayer, trust, and hope in Christ.', true),
  ('a1000000-0000-4000-8000-000000000014', 'ANTHONY_OF_PADUA', 'St. Anthony of Padua', 'A mentor of perseverance, learning, and care for the poor.', true),
  ('a1000000-0000-4000-8000-000000000015', 'AUGUSTINE_OF_HIPPO', 'St. Augustine of Hippo', 'A mentor of conversion, truth, and hearts returning to God.', true),
  ('a1000000-0000-4000-8000-000000000016', 'CATHERINE_OF_SIENA', 'St. Catherine of Siena', 'A mentor of courage, truth, and love for the Church.', true),
  ('a1000000-0000-4000-8000-000000000017', 'CECILIA', 'St. Cecilia', 'A mentor of joyful worship, purity, and courageous witness.', true),
  ('a1000000-0000-4000-8000-000000000018', 'DOMINIC', 'St. Dominic', 'A mentor of preaching, study, and charity rooted in truth.', true),
  ('a1000000-0000-4000-8000-000000000019', 'DYMPHNA', 'St. Dymphna', 'A mentor of compassion, peace of mind, and courageous trust.', true),
  ('a1000000-0000-4000-8000-000000000020', 'FRANCIS_XAVIER', 'St. Francis Xavier', 'A mentor of mission, generosity, and bringing Christ to others.', true),
  ('a1000000-0000-4000-8000-000000000021', 'JOHN_PAUL_II', 'St. John Paul II', 'A mentor of human dignity, courage, and joyful faith.', true),
  ('a1000000-0000-4000-8000-000000000022', 'JOHN_THE_EVANGELIST', 'St. John the Evangelist', 'A mentor of faithful friendship, love, and bold witness.', true),
  ('a1000000-0000-4000-8000-000000000023', 'JUAN_DIEGO', 'St. Juan Diego', 'A mentor of humility, obedience, and sharing hope with others.', true),
  ('a1000000-0000-4000-8000-000000000024', 'MAXIMILIAN_KOLBE', 'St. Maximilian Kolbe', 'A mentor of self-giving love, courage, and hope amid suffering.', true),
  ('a1000000-0000-4000-8000-000000000025', 'MICHAEL_THE_ARCHANGEL', 'St. Michael the Archangel', 'A mentor of spiritual courage, protection, and fidelity to God.', true),
  ('a1000000-0000-4000-8000-000000000026', 'MONICA', 'St. Monica', 'A mentor of patient prayer, perseverance, and hopeful love.', true),
  ('a1000000-0000-4000-8000-000000000027', 'NICHOLAS', 'St. Nicholas', 'A mentor of secret generosity, care for children, and compassion.', true),
  ('a1000000-0000-4000-8000-000000000028', 'PADRE_PIO', 'St. Padre Pio', 'A mentor of prayer, suffering offered in love, and reconciliation.', true),
  ('a1000000-0000-4000-8000-000000000029', 'PATRICK', 'St. Patrick', 'A mentor of missionary courage, forgiveness, and faithful service.', true),
  ('a1000000-0000-4000-8000-000000000030', 'PAUL', 'St. Paul', 'A mentor of conversion, zeal, and sharing the Gospel boldly.', true),
  ('a1000000-0000-4000-8000-000000000031', 'SEBASTIAN', 'St. Sebastian', 'A mentor of steadfast courage, faithfulness, and hope under trial.', true),
  ('a1000000-0000-4000-8000-000000000032', 'TERESA_OF_AVILA', 'St. Teresa of Ávila', 'A mentor of interior prayer, friendship with God, and courage.', true),
  ('a1000000-0000-4000-8000-000000000033', 'TERESA_OF_CALCUTTA', 'St. Teresa of Calcutta', 'A mentor of merciful service, simplicity, and love for the poor.', true),
  ('a1000000-0000-4000-8000-000000000034', 'THOMAS_AQUINAS', 'St. Thomas Aquinas', 'A mentor of faith, reason, study, and love of truth.', true)
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into competition.demon_definitions (
  id,
  code,
  name,
  title,
  description,
  category,
  silly_personality,
  saint_mentor_id,
  saint_mentor_reason,
  max_hp,
  safety_note,
  is_active
)
values
  ('b1000000-0000-4000-8000-000000000001', 'SCROLLZILLA', 'Scrollzilla', 'The Endless Scroller', 'A tiny red nuisance with enormous thumbs who feeds on notifications, short videos, and bedtime procrastination.', 'DISTRACTION', 'Carries three phones but never remembers where any of them are.', 'a1000000-0000-4000-8000-000000000001', 'Discernment and ordered attention expose Scrollzilla tricks.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000002', 'SNOOZLEUMP', 'Snoozleump', 'The Blanket Commander', 'A sleepy blob that declares every responsibility can safely wait until tomorrow.', 'SLOTH', 'Wears a pillow as a crown and snores during his own speeches.', 'a1000000-0000-4000-8000-000000000002', 'Steady work, responsibility, and quiet service weaken Snoozleump.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000003', 'GRUMBLEPUFF', 'Grumblepuff', 'The Complaint Cloud', 'A smoky little grouch who turns minor inconvenience into a five-act tragedy.', 'ANGER', 'Gets angry when soup is too hot and angrier when it gets cold.', 'a1000000-0000-4000-8000-000000000003', 'Gentleness and patient speech directly counter reactive anger.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000004', 'BRAGGLESNOUT', 'Bragglesnout', 'The Tiny Trumpeter', 'A purple horned show-off who announces every good deed with imaginary trumpets.', 'PRIDE', 'Awards himself trophies for attending meetings he scheduled.', 'a1000000-0000-4000-8000-000000000004', 'Her little way of hidden love defeats the need to be impressive.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000005', 'SNACKASAURUS', 'Snackasaurus', 'The Bottomless Muncher', 'A round demon who insists every emotion requires a snack and every snack requires another snack.', 'GLUTTONY', 'Keeps emergency cupcakes in an emergency cupcake.', 'a1000000-0000-4000-8000-000000000005', 'Moderation, order, and rhythm make excess lose its power.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000006', 'PEEKABOOZE', 'Peekabooze', 'The Comparison Gremlin', 'A green gremlin who peeks at everyone else life and edits out all their struggles.', 'ENVY', 'Owns binoculars that only point toward other peoples blessings.', 'a1000000-0000-4000-8000-000000000006', 'Gratitude, simplicity, and joy in others good expose envy.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000007', 'WOBBLEKNEES', 'Wobbleknees', 'The Cowardly Catastrophizer', 'A nervous demon who predicts twelve disasters before breakfast and hides behind a very small shield.', 'FEAR', 'Screams whenever his own cape touches him.', 'a1000000-0000-4000-8000-000000000007', 'Courageous obedience despite fear defeats his exaggerations.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000008', 'WHISPERWHOMP', 'Whisperwhomp', 'The Discouragement Mumbler', 'A shadowy fuzzball who whispers that past failure proves future effort is pointless.', 'DISCOURAGEMENT', 'Practices dramatic sighing in front of a mirror.', 'a1000000-0000-4000-8000-000000000008', 'His repentance and return after failure show that falling is not the end.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000009', 'GOSSIPGOB', 'Gossipgob', 'The Rumor Collector', 'A long-eared goblin who collects half-stories and adds three dramatic details for free.', 'GOSSIP', 'Begins every sentence with I probably should not say this, but.', 'a1000000-0000-4000-8000-000000000009', 'Joy, charity, and practical wisdom expose careless speech.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000010', 'SHINYGRAB', 'Shinygrab', 'The Checkout Goblin', 'A gold-eyed goblin who thinks every limited-time offer is a spiritual emergency.', 'GREED', 'Buys storage boxes to organize the storage boxes he already bought.', 'a1000000-0000-4000-8000-000000000010', 'Generosity and love of people over possessions defeat Shinygrab.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000011', 'FOGGLES', 'Foggles', 'The Confusion Puff', 'A blue floating eyeball surrounded by fog who makes every simple decision feel like a doctoral thesis.', 'CONFUSION', 'Needs a flowchart to decide whether to make a flowchart.', 'a1000000-0000-4000-8000-000000000001', 'Discernment, clarity, and ordered choices disperse the fog.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000012', 'SNEAKYPEEKY', 'Sneakypeeky', 'The Screen-Corner Creeper', 'A pink winged imp who hides harmful content behind boredom, secrecy, and just one look.', 'IMPURITY', 'Wears sunglasses indoors because he thinks it makes him invisible.', 'a1000000-0000-4000-8000-000000000011', 'Purity, dignity, forgiveness, and courage stand against objectification and secrecy.', 100, 'For repeated compulsive behavior, encourage confidential support from a trusted adult, priest, counselor, or qualified professional; software is not treatment.', true)
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  silly_personality = excluded.silly_personality,
  saint_mentor_id = excluded.saint_mentor_id,
  saint_mentor_reason = excluded.saint_mentor_reason,
  max_hp = excluded.max_hp,
  safety_note = excluded.safety_note,
  is_active = excluded.is_active;

insert into competition.demon_virtue_affinities (demon_id, virtue_code, affinity_type)
values
  ('b1000000-0000-4000-8000-000000000001', 'DISCIPLINE', 'primary'), ('b1000000-0000-4000-8000-000000000001', 'WISDOM', 'secondary'), ('b1000000-0000-4000-8000-000000000001', 'PERSEVERANCE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000002', 'DISCIPLINE', 'primary'), ('b1000000-0000-4000-8000-000000000002', 'PERSEVERANCE', 'secondary'), ('b1000000-0000-4000-8000-000000000002', 'CHARITY', 'secondary'),
  ('b1000000-0000-4000-8000-000000000003', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000003', 'COURAGE', 'secondary'), ('b1000000-0000-4000-8000-000000000003', 'WISDOM', 'secondary'),
  ('b1000000-0000-4000-8000-000000000004', 'HUMILITY', 'primary'), ('b1000000-0000-4000-8000-000000000004', 'CHARITY', 'secondary'), ('b1000000-0000-4000-8000-000000000004', 'WISDOM', 'secondary'),
  ('b1000000-0000-4000-8000-000000000005', 'DISCIPLINE', 'primary'), ('b1000000-0000-4000-8000-000000000005', 'WISDOM', 'secondary'), ('b1000000-0000-4000-8000-000000000005', 'PERSEVERANCE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000006', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000006', 'HUMILITY', 'secondary'), ('b1000000-0000-4000-8000-000000000006', 'FAITH', 'secondary'),
  ('b1000000-0000-4000-8000-000000000007', 'COURAGE', 'primary'), ('b1000000-0000-4000-8000-000000000007', 'FAITH', 'secondary'), ('b1000000-0000-4000-8000-000000000007', 'PERSEVERANCE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000008', 'PERSEVERANCE', 'primary'), ('b1000000-0000-4000-8000-000000000008', 'FAITH', 'secondary'), ('b1000000-0000-4000-8000-000000000008', 'COURAGE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000009', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000009', 'WISDOM', 'secondary'), ('b1000000-0000-4000-8000-000000000009', 'HUMILITY', 'secondary'),
  ('b1000000-0000-4000-8000-000000000010', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000010', 'DISCIPLINE', 'secondary'), ('b1000000-0000-4000-8000-000000000010', 'WISDOM', 'secondary'),
  ('b1000000-0000-4000-8000-000000000011', 'WISDOM', 'primary'), ('b1000000-0000-4000-8000-000000000011', 'FAITH', 'secondary'), ('b1000000-0000-4000-8000-000000000011', 'COURAGE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000012', 'PURITY', 'primary'), ('b1000000-0000-4000-8000-000000000012', 'COURAGE', 'secondary'), ('b1000000-0000-4000-8000-000000000012', 'DISCIPLINE', 'secondary')
on conflict (demon_id, virtue_code) do update
set affinity_type = excluded.affinity_type;

insert into competition.demon_attacks (id, demon_id, code, name, description, target_virtue_code, virtue_decrease)
values
  ('c1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'LATE_NIGHT_SCROLLING', 'One More Video', 'Keeps the user scrolling after bedtime.', 'DISCIPLINE', 6),
  ('c1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'NOTIFICATION_STORM', 'Notification Confetti', 'Interrupts prayer, work, and family time.', 'WISDOM', 4),
  ('c1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'AVOID_THE_TASK', 'Productive-Looking Procrastination', 'Makes distraction feel useful while the real task remains untouched.', 'PERSEVERANCE', 5),
  ('c1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000002', 'SNOOZE_AGAIN', 'The Sacred Snooze Button', 'Encourages repeated delays after waking.', 'DISCIPLINE', 5),
  ('c1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000002', 'TOMORROW_TRAP', 'Tomorrow Is Definitely Better', 'Pushes necessary work into an imaginary perfect future.', 'PERSEVERANCE', 6),
  ('c1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000002', 'SERVICE_AVOIDANCE', 'Someone Else Will Do It', 'Makes service feel inconvenient and optional.', 'CHARITY', 4),
  ('c1000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000003', 'SHARP_REPLY', 'Instant Keyboard Thunder', 'Pushes the user to respond harshly before understanding.', 'CHARITY', 6),
  ('c1000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000003', 'RESENTMENT_LOOP', 'Replay the Offense', 'Repeats an offense mentally until it feels larger.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000003', 'AVOID_HARD_CONVERSATION', 'Silent Volcano', 'Avoids honest conversation while resentment builds.', 'COURAGE', 4),
  ('c1000000-0000-4000-8000-000000000010', 'b1000000-0000-4000-8000-000000000004', 'NEED_TO_BE_RIGHT', 'Actually, Technically', 'Turns every conversation into a contest.', 'HUMILITY', 6),
  ('c1000000-0000-4000-8000-000000000011', 'b1000000-0000-4000-8000-000000000004', 'SEEK_PRAISE', 'Applause Vacuum', 'Makes good actions feel worthless unless others notice.', 'CHARITY', 4),
  ('c1000000-0000-4000-8000-000000000012', 'b1000000-0000-4000-8000-000000000004', 'REFUSE_CORRECTION', 'Armor of Excuses', 'Rejects useful correction before considering it.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000013', 'b1000000-0000-4000-8000-000000000005', 'EMOTIONAL_EATING', 'Sad Snack Summoning', 'Uses food to avoid processing emotion.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000014', 'b1000000-0000-4000-8000-000000000005', 'SECOND_PORTION', 'The Plate Refill Spell', 'Pushes the user past reasonable satisfaction.', 'DISCIPLINE', 5),
  ('c1000000-0000-4000-8000-000000000015', 'b1000000-0000-4000-8000-000000000005', 'ALL_OR_NOTHING', 'Diet Drama', 'Turns one imperfect choice into giving up completely.', 'PERSEVERANCE', 4),
  ('c1000000-0000-4000-8000-000000000016', 'b1000000-0000-4000-8000-000000000006', 'SOCIAL_COMPARISON', 'Highlight-Reel Vision', 'Compares ordinary life to selected images of others.', 'HUMILITY', 5),
  ('c1000000-0000-4000-8000-000000000017', 'b1000000-0000-4000-8000-000000000006', 'RESENT_SUCCESS', 'Why Them', 'Turns another person success into resentment.', 'CHARITY', 6),
  ('c1000000-0000-4000-8000-000000000018', 'b1000000-0000-4000-8000-000000000006', 'FORGOTTEN_BLESSINGS', 'Blessing Blindfold', 'Hides what is already good in the user life.', 'FAITH', 4),
  ('c1000000-0000-4000-8000-000000000019', 'b1000000-0000-4000-8000-000000000007', 'AVOID_FIRST_STEP', 'Maybe Never Is Safer', 'Makes the first step feel more dangerous than avoidance.', 'COURAGE', 6),
  ('c1000000-0000-4000-8000-000000000020', 'b1000000-0000-4000-8000-000000000007', 'WORST_CASE_LOOP', 'Disaster Slideshow', 'Cycles through imagined worst-case outcomes.', 'FAITH', 5),
  ('c1000000-0000-4000-8000-000000000021', 'b1000000-0000-4000-8000-000000000007', 'QUIT_EARLY', 'Emergency Exit Everywhere', 'Encourages quitting before enough effort has been made.', 'PERSEVERANCE', 5),
  ('c1000000-0000-4000-8000-000000000022', 'b1000000-0000-4000-8000-000000000008', 'FAILURE_DEFINES_YOU', 'The Permanent Label', 'Treats one failure as the user complete identity.', 'PERSEVERANCE', 7),
  ('c1000000-0000-4000-8000-000000000023', 'b1000000-0000-4000-8000-000000000008', 'GOD_IS_DISTANT', 'He Is Not Listening', 'Tempts the user to abandon prayer when consolation is absent.', 'FAITH', 6),
  ('c1000000-0000-4000-8000-000000000024', 'b1000000-0000-4000-8000-000000000008', 'DO_NOT_TRY', 'Pre-Defeated', 'Convincingly loses battles before they begin.', 'COURAGE', 5),
  ('c1000000-0000-4000-8000-000000000025', 'b1000000-0000-4000-8000-000000000009', 'SHARE_RUMOR', 'Pass It Along', 'Encourages sharing information that is unverified or unnecessary.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000026', 'b1000000-0000-4000-8000-000000000009', 'MOCK_PERSON', 'Comedy at Their Expense', 'Uses another person weakness to gain attention.', 'CHARITY', 7),
  ('c1000000-0000-4000-8000-000000000027', 'b1000000-0000-4000-8000-000000000009', 'MORAL_SUPERIORITY', 'Concerned-Looking Pride', 'Disguises judgment as concern.', 'HUMILITY', 5),
  ('c1000000-0000-4000-8000-000000000028', 'b1000000-0000-4000-8000-000000000010', 'IMPULSE_PURCHASE', 'Buy Now, Discern Never', 'Turns a desire into an immediate purchase.', 'DISCIPLINE', 6),
  ('c1000000-0000-4000-8000-000000000029', 'b1000000-0000-4000-8000-000000000010', 'POSSESSION_IDENTITY', 'You Are What You Own', 'Connects personal worth to possessions and status.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000030', 'b1000000-0000-4000-8000-000000000010', 'HOARD_USEFUL_ITEMS', 'Maybe Someday Mountain', 'Keeps useful goods away from people who need them.', 'CHARITY', 5),
  ('c1000000-0000-4000-8000-000000000031', 'b1000000-0000-4000-8000-000000000011', 'OVERTHINK_DECISION', 'Infinite Option Parade', 'Adds unnecessary options until no action feels possible.', 'WISDOM', 7),
  ('c1000000-0000-4000-8000-000000000032', 'b1000000-0000-4000-8000-000000000011', 'SEEK_ENDLESS_SIGNS', 'One More Sign', 'Avoids reasonable decisions by demanding absolute certainty.', 'FAITH', 5),
  ('c1000000-0000-4000-8000-000000000033', 'b1000000-0000-4000-8000-000000000011', 'FEAR_COMMITMENT', 'Decision Doorway Freeze', 'Makes commitment feel more dangerous than indecision.', 'COURAGE', 5),
  ('c1000000-0000-4000-8000-000000000034', 'b1000000-0000-4000-8000-000000000012', 'TRIGGERING_CONTENT', 'Just One Look', 'Presents harmful or objectifying content as harmless curiosity.', 'PURITY', 8),
  ('c1000000-0000-4000-8000-000000000035', 'b1000000-0000-4000-8000-000000000012', 'SECRECY', 'Nobody Has to Know', 'Uses isolation and shame to prevent seeking help.', 'COURAGE', 6),
  ('c1000000-0000-4000-8000-000000000036', 'b1000000-0000-4000-8000-000000000012', 'LATE_NIGHT_WEAKNESS', 'Midnight Ambush', 'Targets tiredness, privacy, and unstructured screen use.', 'DISCIPLINE', 6)
on conflict (id) do update
set
  demon_id = excluded.demon_id,
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  target_virtue_code = excluded.target_virtue_code,
  virtue_decrease = excluded.virtue_decrease;

insert into competition.demon_defenses (id, demon_id, code, name, challenge, reward_virtue_code, virtue_increase, demon_damage)
values
  ('d1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'PHONE_SIX_FEET_AWAY', 'The Six-Foot Exile', 'Place the phone at least six feet away for 30 minutes or before sleep.', 'DISCIPLINE', 7, 30),
  ('d1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'FOCUS_MODE', 'Silence the Bells', 'Enable Focus Mode and complete one uninterrupted 25-minute session.', 'WISDOM', 5, 25),
  ('d1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'SCRIPTURE_BEFORE_SCREEN', 'Word Before World', 'Read the daily Gospel before opening social media.', 'PERSEVERANCE', 6, 25),
  ('d1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000002', 'MAKE_BED', 'First Victory', 'Get up and make the bed immediately.', 'DISCIPLINE', 4, 20),
  ('d1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000002', 'TWENTY_MINUTE_TASK', 'Twenty-Minute Charge', 'Work on the most avoided task for 20 focused minutes.', 'PERSEVERANCE', 7, 30),
  ('d1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000002', 'HIDDEN_SERVICE', 'Quiet Hands', 'Complete one useful act of service without seeking recognition.', 'CHARITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000003', 'TEN_MINUTE_PAUSE', 'Lower the Drawbridge', 'Wait 10 minutes before responding and reread your message.', 'CHARITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000003', 'PRAY_FOR_PERSON', 'Reverse the Flame', 'Pray sincerely for the person who upset you.', 'WISDOM', 5, 25),
  ('d1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000003', 'CALM_CONVERSATION', 'Speak the Truth Gently', 'Have one direct, respectful conversation instead of avoiding or exploding.', 'COURAGE', 7, 30),
  ('d1000000-0000-4000-8000-000000000010', 'b1000000-0000-4000-8000-000000000004', 'ADMIT_MISTAKE', 'Drop the Trophy', 'Admit one mistake clearly without adding an excuse.', 'HUMILITY', 8, 35),
  ('d1000000-0000-4000-8000-000000000011', 'b1000000-0000-4000-8000-000000000004', 'HIDDEN_KINDNESS', 'Invisible Victory', 'Perform one act of kindness and tell no one.', 'CHARITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000012', 'b1000000-0000-4000-8000-000000000004', 'LISTEN_FULLY', 'Close the Trumpet', 'Listen without interrupting or preparing your reply.', 'WISDOM', 5, 25),
  ('d1000000-0000-4000-8000-000000000013', 'b1000000-0000-4000-8000-000000000005', 'WATER_AND_WAIT', 'The Ten-Minute Truce', 'Drink water and wait 10 minutes before deciding whether to eat.', 'WISDOM', 5, 20),
  ('d1000000-0000-4000-8000-000000000014', 'b1000000-0000-4000-8000-000000000005', 'MINDFUL_PORTION', 'One Plate Pact', 'Choose a reasonable portion and eat without a screen.', 'DISCIPLINE', 7, 30),
  ('d1000000-0000-4000-8000-000000000015', 'b1000000-0000-4000-8000-000000000005', 'RETURN_NEXT_MEAL', 'No Drama Reset', 'After an imperfect choice, return to moderation at the next meal.', 'PERSEVERANCE', 6, 25),
  ('d1000000-0000-4000-8000-000000000016', 'b1000000-0000-4000-8000-000000000006', 'SOCIAL_FAST', 'Close the Binoculars', 'Take a 24-hour break from the app that triggers comparison.', 'HUMILITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000017', 'b1000000-0000-4000-8000-000000000006', 'CONGRATULATE_PERSON', 'Celebrate Their Victory', 'Congratulate someone sincerely and specifically.', 'CHARITY', 7, 30),
  ('d1000000-0000-4000-8000-000000000018', 'b1000000-0000-4000-8000-000000000006', 'FIVE_BLESSINGS', 'Open the Blessing Book', 'Write five concrete blessings from today.', 'FAITH', 5, 25),
  ('d1000000-0000-4000-8000-000000000019', 'b1000000-0000-4000-8000-000000000007', 'ONE_BRAVE_STEP', 'One Step Forward', 'Take one concrete step toward the responsibility you have avoided.', 'COURAGE', 8, 35),
  ('d1000000-0000-4000-8000-000000000020', 'b1000000-0000-4000-8000-000000000007', 'OUR_FATHER_SLOWLY', 'Trust the Father', 'Pray the Our Father slowly and identify the next controllable action.', 'FAITH', 6, 25),
  ('d1000000-0000-4000-8000-000000000021', 'b1000000-0000-4000-8000-000000000007', 'FINISH_SMALL_COMMITMENT', 'Hold the Line', 'Finish one small commitment before changing direction.', 'PERSEVERANCE', 6, 25),
  ('d1000000-0000-4000-8000-000000000022', 'b1000000-0000-4000-8000-000000000008', 'RETURN_TODAY', 'Begin Again', 'Resume one abandoned good habit today for at least five minutes.', 'PERSEVERANCE', 9, 35),
  ('d1000000-0000-4000-8000-000000000023', 'b1000000-0000-4000-8000-000000000008', 'PSALM_OF_HOPE', 'Answer the Whisper', 'Read a Psalm of hope and write one sentence of truth.', 'FAITH', 6, 25),
  ('d1000000-0000-4000-8000-000000000024', 'b1000000-0000-4000-8000-000000000008', 'ASK_FOR_SUPPORT', 'Call Reinforcements', 'Ask a trusted person for prayer, encouragement, or accountability.', 'COURAGE', 7, 30),
  ('d1000000-0000-4000-8000-000000000025', 'b1000000-0000-4000-8000-000000000009', 'VERIFY_OR_SILENCE', 'Lock the Rumor Chest', 'Do not repeat the story unless it is true, necessary, and charitable.', 'WISDOM', 6, 25),
  ('d1000000-0000-4000-8000-000000000026', 'b1000000-0000-4000-8000-000000000009', 'SPEAK_GOOD', 'Replace It with Honor', 'Say one sincere good thing about the person instead.', 'CHARITY', 7, 30),
  ('d1000000-0000-4000-8000-000000000027', 'b1000000-0000-4000-8000-000000000009', 'EXAMINE_MOTIVE', 'Check the Mirror', 'Write why you wanted to share the information before speaking.', 'HUMILITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000028', 'b1000000-0000-4000-8000-000000000010', 'WAIT_24_HOURS', 'The Discernment Delay', 'Wait 24 hours before making a nonessential purchase.', 'DISCIPLINE', 7, 30),
  ('d1000000-0000-4000-8000-000000000029', 'b1000000-0000-4000-8000-000000000010', 'NEED_TEST', 'Need, Use, Cost', 'Write what happens if you do not buy it, how often it will be used, and its full cost.', 'WISDOM', 6, 25),
  ('d1000000-0000-4000-8000-000000000030', 'b1000000-0000-4000-8000-000000000010', 'GIVE_ITEM', 'Open the Storehouse', 'Donate or give away one useful item in good condition.', 'CHARITY', 7, 30),
  ('d1000000-0000-4000-8000-000000000031', 'b1000000-0000-4000-8000-000000000011', 'FACTS_VALUES_NEXT_STEP', 'Clear the Fog', 'Write the known facts, the value involved, and the next reasonable step.', 'WISDOM', 8, 35),
  ('d1000000-0000-4000-8000-000000000032', 'b1000000-0000-4000-8000-000000000011', 'PRAY_AND_DECIDE', 'Pray, Then Move', 'Pray briefly, choose among morally good options, and set a deadline.', 'FAITH', 6, 25),
  ('d1000000-0000-4000-8000-000000000033', 'b1000000-0000-4000-8000-000000000011', 'SMALL_COMMITMENT', 'Cross the Threshold', 'Make one small reversible commitment today.', 'COURAGE', 6, 25),
  ('d1000000-0000-4000-8000-000000000034', 'b1000000-0000-4000-8000-000000000012', 'LEAVE_TRIGGER', 'Exit the Room', 'Immediately close the content and physically leave the triggering environment.', 'PURITY', 8, 35),
  ('d1000000-0000-4000-8000-000000000035', 'b1000000-0000-4000-8000-000000000012', 'CONTACT_ACCOUNTABILITY', 'Break the Secrecy', 'Contact a trusted accountability person with a simple request for support.', 'COURAGE', 7, 30),
  ('d1000000-0000-4000-8000-000000000036', 'b1000000-0000-4000-8000-000000000012', 'DEVICE_BOUNDARY', 'Guard the Gate', 'Move the device out of the private space and enable content restrictions.', 'DISCIPLINE', 7, 30)
on conflict (id) do update
set
  demon_id = excluded.demon_id,
  code = excluded.code,
  name = excluded.name,
  challenge = excluded.challenge,
  reward_virtue_code = excluded.reward_virtue_code,
  virtue_increase = excluded.virtue_increase,
  demon_damage = excluded.demon_damage;

insert into competition.demon_defeat_rewards (demon_id, virtue_code, virtue_increase, xp_reward)
values
  ('b1000000-0000-4000-8000-000000000001', 'DISCIPLINE', 10, 100),
  ('b1000000-0000-4000-8000-000000000002', 'DISCIPLINE', 10, 100),
  ('b1000000-0000-4000-8000-000000000003', 'CHARITY', 10, 110),
  ('b1000000-0000-4000-8000-000000000004', 'HUMILITY', 10, 120),
  ('b1000000-0000-4000-8000-000000000005', 'DISCIPLINE', 9, 100),
  ('b1000000-0000-4000-8000-000000000006', 'CHARITY', 10, 105),
  ('b1000000-0000-4000-8000-000000000007', 'COURAGE', 10, 115),
  ('b1000000-0000-4000-8000-000000000008', 'PERSEVERANCE', 12, 125),
  ('b1000000-0000-4000-8000-000000000009', 'CHARITY', 10, 110),
  ('b1000000-0000-4000-8000-000000000010', 'CHARITY', 10, 110),
  ('b1000000-0000-4000-8000-000000000011', 'WISDOM', 11, 120),
  ('b1000000-0000-4000-8000-000000000012', 'PURITY', 12, 130)
on conflict (demon_id) do update
set
  virtue_code = excluded.virtue_code,
  virtue_increase = excluded.virtue_increase,
  xp_reward = excluded.xp_reward;

insert into competition.badge_requirement_definitions (
  id,
  badge_id,
  requirement_type,
  required_value,
  description,
  rules,
  display_order
)
values
  ('e1000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000005', 'daily_honesty_reflection', 7, 'Complete seven daily honesty reflections.', '{"virtue":"truth"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000006', 'prayer_days', 7, 'Seven days of prayer.', '{"virtue":"faith"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000003', '80000000-0000-4000-8000-000000000006', 'scripture_plan_completed', 1, 'One completed Scripture plan.', '{"virtue":"faith"}'::jsonb, 2),
  ('e1000000-0000-4000-8000-000000000004', '80000000-0000-4000-8000-000000000006', 'trust_act_during_difficulty', 1, 'One act of trust during difficulty.', '{"virtue":"faith"}'::jsonb, 3),
  ('e1000000-0000-4000-8000-000000000005', '80000000-0000-4000-8000-000000000007', 'scripture_reading_sessions', 10, 'Complete ten Scripture reading sessions.', '{"virtue":"wisdom"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000006', '80000000-0000-4000-8000-000000000008', 'daily_prayer_streak', 14, 'Maintain a fourteen-day prayer streak.', '{"virtue":"hope"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000007', '80000000-0000-4000-8000-000000000009', 'service_acts', 5, 'Complete five acts of service.', '{"virtue":"readiness"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000008', '80000000-0000-4000-8000-000000000010', 'daily_rule_of_life_streak', 21, 'Maintain a twenty-one-day rule-of-life streak.', '{"virtue":"righteousness"}'::jsonb, 1)
on conflict (id) do update
set
  badge_id = excluded.badge_id,
  requirement_type = excluded.requirement_type,
  required_value = excluded.required_value,
  description = excluded.description,
  rules = excluded.rules,
  display_order = excluded.display_order;

insert into competition.badge_requirement_activity_rules (
  badge_requirement_id,
  activity_code,
  progress_mode,
  metadata_filter
)
values
  ('e1000000-0000-4000-8000-000000000001', 'HONESTY_REFLECTION', 'distinct_days', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000002', 'PRAYER', 'distinct_days', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000003', 'SCRIPTURE', 'activity_quantity', '{"planCompleted":true}'::jsonb),
  ('e1000000-0000-4000-8000-000000000004', 'TRUST_ACT', 'activity_quantity', '{"duringDifficulty":true}'::jsonb),
  ('e1000000-0000-4000-8000-000000000005', 'SCRIPTURE', 'activity_quantity', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000006', 'PRAYER', 'consecutive_days', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000007', 'SERVICE', 'activity_quantity', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000008', 'RULE_OF_LIFE', 'consecutive_days', '{}'::jsonb)
on conflict (badge_requirement_id) do update
set
  activity_code = excluded.activity_code,
  progress_mode = excluded.progress_mode,
  metadata_filter = excluded.metadata_filter;

insert into competition.demon_defense_activity_rules (
  defense_id,
  activity_code,
  metadata_filter
)
values
  ('d1000000-0000-4000-8000-000000000003', 'SCRIPTURE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000006', 'SERVICE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000008', 'PRAYER', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000023', 'SCRIPTURE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000020', 'PRAYER', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000030', 'SERVICE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000032', 'PRAYER', '{}'::jsonb)
on conflict (defense_id) do update
set
  activity_code = excluded.activity_code,
  metadata_filter = excluded.metadata_filter;

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
  ('30000000-0000-4000-8000-000000000006', 'FASTING_OFFERING', 'FASTING', 'Fasting offering', 'Points for a voluntary fast.', 35, 1, 3, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000007', 'HONESTY_REFLECTION', 'HONESTY_REFLECTION', 'Honesty reflection', 'Points for a truthful daily reflection.', 10, 1, 7, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000008', 'TRUST_ACT', 'TRUST_ACT', 'Act of trust', 'Points for acting in trust during difficulty.', 25, 1, 5, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000009', 'RULE_OF_LIFE', 'RULE_OF_LIFE', 'Rule of life completed', 'Points for completing a daily rule of life.', 30, 1, 7, now() - interval '1 year', true)
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
  ('40000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'ROSARY', ((date '2026-07-01' + time '11:30') at time zone 'America/Chicago'), ((date '2026-07-01' + time '12:00') at time zone 'America/Chicago'), 1800, 1, 'verified', 'manual', 'e0000000-0000-4000-8000-000000000001', 'US', 'seed-test-rosary-july-1', '{"mysteries":"joyful","note":"July rosary day 1"}'::jsonb),
  ('40000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'SCRIPTURE', now() - interval '1 day 25 minutes', now() - interval '1 day', 1500, 2, 'verified', 'challenge', 'e0000000-0000-4000-8000-000000000001', 'US', 'seed-test-scripture-1', '{"passage":"Luke 10:25-37","translation":"NRSVCE"}'::jsonb),
  ('40000000-0000-4000-8000-000000000003', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'PRAYER', now() - interval '2 days 10 minutes', now() - interval '2 days', 600, 1, 'self_reported', 'manual', 'e0000000-0000-4000-8000-000000000001', 'US', 'seed-test-prayer-1', '{"intention":"Peace in the community"}'::jsonb),
  ('40000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'ROSARY', ((date '2026-07-15' + time '11:30') at time zone 'America/Mexico_City'), ((date '2026-07-15' + time '12:00') at time zone 'America/Mexico_City'), 1500, 1, 'verified', 'live_prayer', 'e0000000-0000-4000-8000-000000000003', 'MX', 'seed-maria-rosary-1', '{"mysteries":"sorrowful","groupPrayer":true}'::jsonb),
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

-- Seed 25 distinct completed Rosary days for test@test.com in the fixed,
-- historical month of July 2026. The timestamps are noon America/Chicago so
-- each entry remains on its intended local calendar day.
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
select
  ('40000000-0000-4000-8000-' || lpad((day_number + 5)::text, 12, '0'))::uuid,
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'::uuid,
  'ROSARY',
  ((date '2026-07-01' + (day_number - 1) + time '11:30') at time zone 'America/Chicago'),
  ((date '2026-07-01' + (day_number - 1) + time '12:00') at time zone 'America/Chicago'),
  1800,
  1,
  'verified',
  'manual',
  'e0000000-0000-4000-8000-000000000001'::uuid,
  'US',
  'seed-test-rosary-july-' || day_number,
  jsonb_build_object('mysteries', 'joyful', 'note', 'July rosary day ' || day_number)
from generate_series(2, 25) as day_number
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

insert into competition.user_virtues (user_id, virtue_code, current_value, version)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'FAITH', 62, 1),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'DISCIPLINE', 66, 3),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'COURAGE', 52, 1),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'WISDOM', 57, 1),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'CHARITY', 55, 1),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'PURITY', 50, 1),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'PERSEVERANCE', 54, 1),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'HUMILITY', 50, 1),
  ('11111111-1111-4111-8111-111111111111', 'FAITH', 65, 1),
  ('11111111-1111-4111-8111-111111111111', 'DISCIPLINE', 60, 1),
  ('11111111-1111-4111-8111-111111111111', 'COURAGE', 62, 2),
  ('11111111-1111-4111-8111-111111111111', 'WISDOM', 65, 2),
  ('11111111-1111-4111-8111-111111111111', 'CHARITY', 74, 3),
  ('11111111-1111-4111-8111-111111111111', 'PURITY', 52, 1),
  ('11111111-1111-4111-8111-111111111111', 'PERSEVERANCE', 58, 1),
  ('11111111-1111-4111-8111-111111111111', 'HUMILITY', 56, 1),
  ('22222222-2222-4222-8222-222222222222', 'FAITH', 52, 1),
  ('22222222-2222-4222-8222-222222222222', 'DISCIPLINE', 55, 1),
  ('22222222-2222-4222-8222-222222222222', 'COURAGE', 50, 1),
  ('22222222-2222-4222-8222-222222222222', 'WISDOM', 54, 1),
  ('22222222-2222-4222-8222-222222222222', 'CHARITY', 55, 1),
  ('22222222-2222-4222-8222-222222222222', 'PURITY', 50, 1),
  ('22222222-2222-4222-8222-222222222222', 'PERSEVERANCE', 52, 1),
  ('22222222-2222-4222-8222-222222222222', 'HUMILITY', 52, 1)
on conflict (user_id, virtue_code) do update
set
  current_value = excluded.current_value,
  version = excluded.version;

insert into competition.user_demon_encounters (
  id,
  user_id,
  demon_id,
  status,
  max_hp,
  current_hp,
  started_at,
  ended_at,
  defeated_at,
  version,
  metadata
)
values
  ('f1000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'b1000000-0000-4000-8000-000000000001', 'active', 100, 70, now() - interval '1 day', null, null, 3, '{"difficulty":"normal"}'::jsonb),
  ('f1000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'b1000000-0000-4000-8000-000000000003', 'defeated', 100, 0, now() - interval '5 days', now() - interval '1 day', now() - interval '1 day', 5, '{"difficulty":"normal"}'::jsonb),
  ('f1000000-0000-4000-8000-000000000003', '22222222-2222-4222-8222-222222222222', 'b1000000-0000-4000-8000-000000000002', 'active', 100, 80, now() - interval '6 hours', null, null, 1, '{"difficulty":"easy"}'::jsonb)
on conflict (id) do update
set
  user_id = excluded.user_id,
  demon_id = excluded.demon_id,
  status = excluded.status,
  max_hp = excluded.max_hp,
  current_hp = excluded.current_hp,
  started_at = excluded.started_at,
  ended_at = excluded.ended_at,
  defeated_at = excluded.defeated_at,
  version = excluded.version,
  metadata = excluded.metadata;

insert into competition.user_demon_defense_assignments (
  id,
  encounter_id,
  defense_id,
  assignment_sequence,
  status,
  assigned_at,
  completed_at,
  metadata
)
values
  ('f2000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', 1, 'completed', now() - interval '20 hours', now() - interval '18 hours', '{"verified":true}'::jsonb),
  ('f2000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000002', 1, 'assigned', now() - interval '2 hours', null, '{}'::jsonb),
  ('f2000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000007', 1, 'completed', now() - interval '4 days', now() - interval '4 days', '{"verified":true}'::jsonb),
  ('f2000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000008', 1, 'completed', now() - interval '3 days', now() - interval '3 days', '{"verified":true}'::jsonb),
  ('f2000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000009', 1, 'completed', now() - interval '2 days', now() - interval '2 days', '{"verified":true}'::jsonb),
  ('f2000000-0000-4000-8000-000000000006', 'f1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000004', 1, 'completed', now() - interval '5 hours', now() - interval '5 hours', '{"verified":true}'::jsonb),
  ('f2000000-0000-4000-8000-000000000007', 'f1000000-0000-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000005', 1, 'assigned', now() - interval '2 hours', null, '{}'::jsonb)
on conflict (id) do update
set
  encounter_id = excluded.encounter_id,
  defense_id = excluded.defense_id,
  assignment_sequence = excluded.assignment_sequence,
  status = excluded.status,
  assigned_at = excluded.assigned_at,
  completed_at = excluded.completed_at,
  metadata = excluded.metadata;

insert into competition.virtue_events (
  id,
  user_id,
  virtue_code,
  encounter_id,
  source_type,
  source_id,
  previous_value,
  delta,
  resulting_value,
  idempotency_key,
  metadata,
  occurred_at
)
values
  ('f3000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'DISCIPLINE', 'f1000000-0000-4000-8000-000000000001', 'demon_attack', 'c1000000-0000-4000-8000-000000000001', 65, -6, 59, 'seed-virtue-scrollzilla-attack', '{"attackCode":"LATE_NIGHT_SCROLLING"}'::jsonb, now() - interval '20 hours'),
  ('f3000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'DISCIPLINE', 'f1000000-0000-4000-8000-000000000001', 'demon_defense', 'f2000000-0000-4000-8000-000000000001', 59, 7, 66, 'seed-virtue-scrollzilla-defense', '{"defenseCode":"PHONE_SIX_FEET_AWAY"}'::jsonb, now() - interval '18 hours'),
  ('f3000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'CHARITY', 'f1000000-0000-4000-8000-000000000002', 'demon_defense', 'f2000000-0000-4000-8000-000000000003', 58, 6, 64, 'seed-virtue-grumblepuff-pause', '{"defenseCode":"TEN_MINUTE_PAUSE"}'::jsonb, now() - interval '4 days'),
  ('f3000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'WISDOM', 'f1000000-0000-4000-8000-000000000002', 'demon_defense', 'f2000000-0000-4000-8000-000000000004', 60, 5, 65, 'seed-virtue-grumblepuff-prayer', '{"defenseCode":"PRAY_FOR_PERSON"}'::jsonb, now() - interval '3 days'),
  ('f3000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'COURAGE', 'f1000000-0000-4000-8000-000000000002', 'demon_defense', 'f2000000-0000-4000-8000-000000000005', 55, 7, 62, 'seed-virtue-grumblepuff-conversation', '{"defenseCode":"CALM_CONVERSATION"}'::jsonb, now() - interval '2 days'),
  ('f3000000-0000-4000-8000-000000000006', '11111111-1111-4111-8111-111111111111', 'CHARITY', 'f1000000-0000-4000-8000-000000000002', 'demon_defeat', 'f1000000-0000-4000-8000-000000000002', 64, 10, 74, 'seed-virtue-grumblepuff-defeat', '{"xpReward":110}'::jsonb, now() - interval '1 day'),
  ('f3000000-0000-4000-8000-000000000007', '22222222-2222-4222-8222-222222222222', 'DISCIPLINE', 'f1000000-0000-4000-8000-000000000003', 'demon_defense', 'f2000000-0000-4000-8000-000000000006', 51, 4, 55, 'seed-virtue-snoozleump-bed', '{"defenseCode":"MAKE_BED"}'::jsonb, now() - interval '5 hours')
on conflict (id) do update
set
  user_id = excluded.user_id,
  virtue_code = excluded.virtue_code,
  encounter_id = excluded.encounter_id,
  source_type = excluded.source_type,
  source_id = excluded.source_id,
  previous_value = excluded.previous_value,
  delta = excluded.delta,
  resulting_value = excluded.resulting_value,
  idempotency_key = excluded.idempotency_key,
  metadata = excluded.metadata,
  occurred_at = excluded.occurred_at;

insert into competition.demon_battle_events (
  id,
  encounter_id,
  event_type,
  attack_id,
  defense_assignment_id,
  virtue_event_id,
  previous_hp,
  demon_damage,
  resulting_hp,
  idempotency_key,
  metadata,
  occurred_at
)
values
  ('f4000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'attack', 'c1000000-0000-4000-8000-000000000001', null, 'f3000000-0000-4000-8000-000000000001', 100, 0, 100, 'seed-battle-scrollzilla-attack', '{"attackCode":"LATE_NIGHT_SCROLLING"}'::jsonb, now() - interval '20 hours'),
  ('f4000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001', 'defense_completed', null, 'f2000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000002', 100, 30, 70, 'seed-battle-scrollzilla-defense', '{"defenseCode":"PHONE_SIX_FEET_AWAY"}'::jsonb, now() - interval '18 hours'),
  ('f4000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000002', 'defense_completed', null, 'f2000000-0000-4000-8000-000000000003', 'f3000000-0000-4000-8000-000000000003', 80, 25, 55, 'seed-battle-grumblepuff-pause', '{"defenseCode":"TEN_MINUTE_PAUSE"}'::jsonb, now() - interval '4 days'),
  ('f4000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000002', 'defense_completed', null, 'f2000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000004', 55, 25, 30, 'seed-battle-grumblepuff-prayer', '{"defenseCode":"PRAY_FOR_PERSON"}'::jsonb, now() - interval '3 days'),
  ('f4000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000002', 'defense_completed', null, 'f2000000-0000-4000-8000-000000000005', 'f3000000-0000-4000-8000-000000000005', 30, 30, 0, 'seed-battle-grumblepuff-conversation', '{"defenseCode":"CALM_CONVERSATION"}'::jsonb, now() - interval '2 days'),
  ('f4000000-0000-4000-8000-000000000006', 'f1000000-0000-4000-8000-000000000002', 'demon_defeated', null, null, 'f3000000-0000-4000-8000-000000000006', 0, 0, 0, 'seed-battle-grumblepuff-defeat', '{"xpReward":110}'::jsonb, now() - interval '1 day'),
  ('f4000000-0000-4000-8000-000000000007', 'f1000000-0000-4000-8000-000000000003', 'defense_completed', null, 'f2000000-0000-4000-8000-000000000006', 'f3000000-0000-4000-8000-000000000007', 100, 20, 80, 'seed-battle-snoozleump-bed', '{"defenseCode":"MAKE_BED"}'::jsonb, now() - interval '5 hours')
on conflict (id) do update
set
  encounter_id = excluded.encounter_id,
  event_type = excluded.event_type,
  attack_id = excluded.attack_id,
  defense_assignment_id = excluded.defense_assignment_id,
  virtue_event_id = excluded.virtue_event_id,
  previous_hp = excluded.previous_hp,
  demon_damage = excluded.demon_damage,
  resulting_hp = excluded.resulting_hp,
  idempotency_key = excluded.idempotency_key,
  metadata = excluded.metadata,
  occurred_at = excluded.occurred_at;

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
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', '80000000-0000-4000-8000-000000000006', 1, 3),
  ('11111111-1111-4111-8111-111111111111', '80000000-0000-4000-8000-000000000002', 4, 5),
  ('22222222-2222-4222-8222-222222222222', '80000000-0000-4000-8000-000000000004', 1, 3)
on conflict (user_id, badge_id) do update
set
  current_value = excluded.current_value,
  required_value = excluded.required_value;

insert into competition.user_badge_requirement_progress (
  user_id,
  badge_requirement_id,
  current_value,
  required_value,
  completed_at
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'e1000000-0000-4000-8000-000000000002', 1, 7, null),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'e1000000-0000-4000-8000-000000000003', 0, 1, null),
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'e1000000-0000-4000-8000-000000000004', 0, 1, null),
  ('11111111-1111-4111-8111-111111111111', 'e1000000-0000-4000-8000-000000000007', 1, 5, null)
on conflict (user_id, badge_requirement_id) do update
set
  current_value = excluded.current_value,
  required_value = excluded.required_value,
  completed_at = excluded.completed_at;

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
  ('50000000-0000-4000-8000-000000000002', 'weekly', 'seed-previous-week', 'Previous Week', date_trunc('week', now()) - interval '1 week', date_trunc('week', now()), 'finalized', date_trunc('week', now()) + interval '1 hour'),
  ('50000000-0000-4000-8000-000000000003', 'daily', 'seed-current-day', 'Today', date_trunc('day', now()), date_trunc('day', now()) + interval '1 day', 'active', null),
  ('50000000-0000-4000-8000-000000000004', 'monthly', 'seed-current-month', 'Current Month', date_trunc('month', now()), date_trunc('month', now()) + interval '1 month', 'active', null),
  ('50000000-0000-4000-8000-000000000005', 'yearly', 'seed-current-year', 'Current Year', date_trunc('year', now()), date_trunc('year', now()) + interval '1 year', 'active', null),
  ('50000000-0000-4000-8000-000000000006', 'season', 'seed-current-season', 'Current Season', date_trunc('quarter', now()), date_trunc('quarter', now()) + interval '3 months', 'active', null)
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
  ('50000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', 'global', 'global', 190, 3, 2, 4, 8),
  ('50000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'global', 'global', 50, 1, 1, 1, 2),
  ('50000000-0000-4000-8000-000000000003', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'global', 'global', 35, 2, 1, 0, 1),
  ('50000000-0000-4000-8000-000000000003', '22222222-2222-4222-8222-222222222222', 'global', 'global', 20, 3, 0, 1, 1),
  ('50000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'global', 'global', 900, 1, 12, 16, 31),
  ('50000000-0000-4000-8000-000000000004', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'global', 'global', 580, 2, 8, 10, 22),
  ('50000000-0000-4000-8000-000000000004', '22222222-2222-4222-8222-222222222222', 'global', 'global', 430, 3, 5, 8, 17),
  ('50000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'global', 'global', 5400, 1, 75, 101, 196),
  ('50000000-0000-4000-8000-000000000005', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'global', 'global', 3200, 2, 49, 67, 124),
  ('50000000-0000-4000-8000-000000000005', '22222222-2222-4222-8222-222222222222', 'global', 'global', 2100, 3, 31, 44, 85),
  ('50000000-0000-4000-8000-000000000006', '11111111-1111-4111-8111-111111111111', 'global', 'global', 1700, 1, 24, 31, 62),
  ('50000000-0000-4000-8000-000000000006', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'global', 'global', 1100, 2, 16, 21, 43),
  ('50000000-0000-4000-8000-000000000006', '22222222-2222-4222-8222-222222222222', 'global', 'global', 850, 3, 11, 15, 32)
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

-- A harmless support request keeps the development dataset complete without
-- exposing a real person's contact details.
insert into app.contact_requests (
  id,
  name,
  email,
  subject,
  other_subject,
  message,
  created_at
)
values (
  'c9000000-0000-4000-8000-000000000001',
  'Seeded Support Request',
  'support@example.com',
  'Content Feedback & Requests',
  null,
  'Seed data used to validate the contact-request workflow.',
  now() - interval '1 day'
)
on conflict (id) do update set
  name = excluded.name,
  email = excluded.email,
  subject = excluded.subject,
  other_subject = excluded.other_subject,
  message = excluded.message,
  created_at = excluded.created_at;

-- Every seeded account must be able to exercise the spiritual-battle UI: its
-- virtue dashboard, a demon encounter, a defense, and the resulting history.
do $$
declare
  seed_user_id uuid;
  expected_virtue_count integer;
begin
  select count(*) into expected_virtue_count
  from competition.virtue_definitions
  where is_active;

  for seed_user_id in
    values
      ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'::uuid),
      ('11111111-1111-4111-8111-111111111111'::uuid),
      ('22222222-2222-4222-8222-222222222222'::uuid)
  loop
    if (select count(*) from competition.user_virtues where user_id = seed_user_id) <> expected_virtue_count
      or not exists (select 1 from competition.user_demon_encounters where user_id = seed_user_id)
      or not exists (
        select 1
        from competition.user_demon_defense_assignments assignment
        join competition.user_demon_encounters encounter on encounter.id = assignment.encounter_id
        where encounter.user_id = seed_user_id
      )
      or not exists (select 1 from competition.virtue_events where user_id = seed_user_id)
      or not exists (
        select 1
        from competition.demon_battle_events battle_event
        join competition.user_demon_encounters encounter on encounter.id = battle_event.encounter_id
        where encounter.user_id = seed_user_id
      )
    then
      raise exception 'Seeded user % is missing spiritual-battle data', seed_user_id;
    end if;
  end loop;
end
$$;

commit;
