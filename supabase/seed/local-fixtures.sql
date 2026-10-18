-- Explicitly local-only development fixtures for user and operational workflows.
--
-- Login credentials (all passwords are 12345678):
--   test@test.com
--   test@admin.com (admin)
--   maria@example.com
--   john@example.com
--
-- This file is intentionally excluded from supabase/config.toml. Run it only
-- through `npm run db:reset:local-fixtures` against local Supabase.

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
  country_code,
  leaderboard_visibility,
  prayer_map_visibility
)
values
  ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'Test User', 'testuser', 'https://i.pravatar.cc/256?u=testuser', 'Faithful Beginner', 'male', 'en', 'America/Chicago', 'US', 'public', 'aggregated'),
  ('33333333-3333-4333-8333-333333333333', 'Test Administrator', 'testadmin', 'https://i.pravatar.cc/256?u=testadmin', 'Administrator', 'male', 'en', 'America/Chicago', 'US', 'public', 'aggregated'),
  ('11111111-1111-4111-8111-111111111111', 'Maria Santos', 'mariasantos', 'https://i.pravatar.cc/256?u=mariasantos', 'Prayer Champion', 'female', 'es', 'America/Mexico_City', 'MX', 'public', 'aggregated'),
  ('22222222-2222-4222-8222-222222222222', 'John Paul', 'johnpaul', 'https://i.pravatar.cc/256?u=johnpaul', 'Scripture Seeker', 'male', 'en', 'America/Chicago', 'US', 'public', 'aggregated')
on conflict (user_id) do update
set
  display_name = excluded.display_name,
  username = excluded.username,
  avatar_url = excluded.avatar_url,
  title = excluded.title,
  gender = excluded.gender,
  preferred_language = excluded.preferred_language,
  timezone = excluded.timezone,
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
-- Competition activity and progress
-- ---------------------------------------------------------------------------

-- Seed explicit badge fixtures below, so keep the canonical activity trigger
-- from awarding the same non-repeatable badges with generated IDs first.
select set_config('api.record_spiritual_activity_badges', 'true', true);

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
  country_code,
  idempotency_key,
  metadata
)
values
  ('40000000-0000-4000-8000-000000000001', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'ROSARY', ((date '2026-07-01' + time '11:30') at time zone 'America/Chicago'), ((date '2026-07-01' + time '12:00') at time zone 'America/Chicago'), 1800, 1, 'verified', 'manual', 'US', 'seed-test-rosary-july-1', '{"mysteries":"joyful","note":"July rosary day 1"}'::jsonb),
  ('40000000-0000-4000-8000-000000000002', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'SCRIPTURE', now() - interval '1 day 25 minutes', now() - interval '1 day', 1500, 2, 'verified', 'challenge', 'US', 'seed-test-scripture-1', '{"passage":"Luke 10:25-37","translation":"NRSVCE"}'::jsonb),
  ('40000000-0000-4000-8000-000000000003', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002', 'PRAYER', now() - interval '2 days 10 minutes', now() - interval '2 days', 600, 1, 'self_reported', 'manual', 'US', 'seed-test-prayer-1', '{"intention":"Peace in the community"}'::jsonb),
  ('40000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'ROSARY', ((date '2026-07-15' + time '11:30') at time zone 'America/Mexico_City'), ((date '2026-07-15' + time '12:00') at time zone 'America/Mexico_City'), 1500, 1, 'verified', 'live_prayer', 'MX', 'seed-maria-rosary-1', '{"mysteries":"sorrowful","groupPrayer":true}'::jsonb),
  ('40000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'SERVICE', now() - interval '2 days', now() - interval '2 days', null, 1, 'verified', 'challenge', 'MX', 'seed-maria-service-1', '{"description":"Prepared meals for a parish outreach"}'::jsonb),
  ('40000000-0000-4000-8000-000000000006', '22222222-2222-4222-8222-222222222222', 'ADORATION', now() - interval '3 hours 45 minutes', now() - interval '3 hours', 2700, 1, 'verified', 'manual', 'US', 'seed-john-adoration-1', '{"parish":"St. Joseph"}'::jsonb)
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
  country_code = excluded.country_code,
  idempotency_key = excluded.idempotency_key,
  metadata = excluded.metadata;

-- Keep the daily Scripture completion fixture linked to its recorded activity.
insert into prayer.daily_scripture_completions (
  user_id,
  reading_date,
  activity_id,
  completed_at
)
values
  (
    '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    current_date - 1,
    '40000000-0000-4000-8000-000000000002',
    now() - interval '1 day'
  )
on conflict (user_id, reading_date) do update
set
  activity_id = excluded.activity_id,
  completed_at = excluded.completed_at;

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
  country_code = excluded.country_code,
  idempotency_key = excluded.idempotency_key,
  metadata = excluded.metadata;

select set_config('api.record_spiritual_activity_badges', '', true);

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

select competition.refresh_leaderboards(true, now());

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
-- Privacy-safe aggregates
-- ---------------------------------------------------------------------------

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
  ('51000000-0000-4000-8000-000000000003', 'country', 'VA', 'Vatican City', 'VA', 41.902900, 12.453400, 590, 112, 0.4100, date_trunc('week', now()), date_trunc('week', now()) + interval '1 week')
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
