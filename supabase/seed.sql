-- Local development seed data.
--
-- Login credentials:
--   email:    test@test.com
--   password: 12345678

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
values (
  '00000000-0000-0000-0000-000000000000',
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
  'authenticated',
  'authenticated',
  'test@test.com',
  crypt('12345678', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"Test User"}'::jsonb,
  now(),
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
values (
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
  jsonb_build_object(
    'sub', '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    'email', 'test@test.com',
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  now(),
  now(),
  now()
)
on conflict (provider_id, provider) do update
set
  user_id = excluded.user_id,
  identity_data = excluded.identity_data,
  updated_at = now();

insert into app.users (id, email, status, email_verified_at)
values (
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
  'test@test.com',
  'active',
  now()
)
on conflict (id) do update
set
  email = excluded.email,
  status = excluded.status,
  email_verified_at = excluded.email_verified_at;

insert into app.user_profiles (user_id, display_name, username)
values (
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
  'Test User',
  'testuser'
)
on conflict (user_id) do update
set
  display_name = excluded.display_name,
  username = excluded.username;

-- user_progress.current_level references this lookup table, so the initial
-- level must exist before a progress row can use its default value of 1.
insert into competition.level_definitions (
  level_number,
  code,
  name,
  description,
  minimum_total_xp
)
values (
  1,
  'beginner',
  'Beginner',
  'Starting level for new users.',
  0
)
on conflict (level_number) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  minimum_total_xp = excluded.minimum_total_xp;

insert into competition.user_progress (user_id)
values ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002')
on conflict (user_id) do nothing;
