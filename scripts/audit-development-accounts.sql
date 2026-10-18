\set ON_ERROR_STOP on
\pset pager off

begin transaction read only;

with known_account(expected_id, expected_email) as (
  values
    ('9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'::uuid, 'test@test.com'::text),
    ('33333333-3333-4333-8333-333333333333'::uuid, 'test@admin.com'::text),
    ('11111111-1111-4111-8111-111111111111'::uuid, 'maria@example.com'::text),
    ('22222222-2222-4222-8222-222222222222'::uuid, 'john@example.com'::text)
)
select
  known_account.expected_id,
  known_account.expected_email,
  case
    when auth_user.id is null then 'absent'
    when auth_user.id = known_account.expected_id
      and lower(auth_user.email) = known_account.expected_email then 'uuid_and_email'
    when auth_user.id = known_account.expected_id then 'uuid'
    else 'email'
  end as match_status,
  auth_user.id as actual_id,
  auth_user.email as actual_email
from known_account
left join auth.users auth_user
  on auth_user.id = known_account.expected_id
  or lower(auth_user.email) = known_account.expected_email
order by known_account.expected_email, auth_user.id;

do $$
begin
  if exists (
    select 1
    from auth.users auth_user
    where auth_user.id = any (array[
      '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'::uuid,
      '33333333-3333-4333-8333-333333333333'::uuid,
      '11111111-1111-4111-8111-111111111111'::uuid,
      '22222222-2222-4222-8222-222222222222'::uuid
    ])
      or lower(auth_user.email) = any (array[
        'test@test.com',
        'test@admin.com',
        'maria@example.com',
        'john@example.com'
      ])
  ) then
    raise exception 'PRODUCTION_DEV_ACCOUNT_PRESENT'
      using errcode = 'P0001',
        detail = 'This read-only audit found a known local fixture account. No account was changed.';
  end if;
end
$$;

commit;
