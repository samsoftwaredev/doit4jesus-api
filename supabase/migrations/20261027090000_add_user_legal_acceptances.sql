-- Append-only evidence of the legal documents accepted by authenticated users.
-- No IP address, device fingerprint, identity document, or birth date is stored.

create table app.user_legal_acceptances (
  user_id uuid not null references app.users(id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  community_guidelines_version text not null,
  accepted_locale text not null check (accepted_locale in ('en', 'es')),
  adult_confirmed boolean not null check (adult_confirmed),
  us_resident_confirmed boolean not null check (us_resident_confirmed),
  accepted_at timestamptz not null default now(),
  primary key (
    user_id,
    terms_version,
    privacy_version,
    community_guidelines_version
  )
);

comment on table app.user_legal_acceptances is
  'Append-only legal acceptance evidence. Rows cascade when the account is deleted.';

alter table app.user_legal_acceptances enable row level security;

revoke all on table app.user_legal_acceptances from public, anon, authenticated;
grant select, insert on table app.user_legal_acceptances to service_role;

create or replace function api.get_current_user_legal_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_created_at timestamptz;
  v_accepted_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  select account.created_at into v_created_at
  from app.users account
  where account.id = v_user_id;

  if not found then
    raise exception 'USER_ACCOUNT_NOT_FOUND' using errcode = 'P0001';
  end if;

  select acceptance.accepted_at into v_accepted_at
  from app.user_legal_acceptances acceptance
  where acceptance.user_id = v_user_id
    and acceptance.terms_version = '2026-10-28'
    and acceptance.privacy_version = '2026-10-28'
    and acceptance.community_guidelines_version = '2026-10-28';

  return jsonb_build_object(
    'accountCreatedAt', v_created_at,
    'acceptedAt', v_accepted_at
  );
end;
$$;

create or replace function api.accept_current_user_legal_documents(
  p_accepted_locale text,
  p_adult_confirmed boolean,
  p_us_resident_confirmed boolean
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_accepted_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if p_accepted_locale not in ('en', 'es') then
    raise exception 'UNSUPPORTED_LEGAL_ACCEPTANCE_LOCALE' using errcode = '22023';
  end if;
  if p_adult_confirmed is distinct from true
    or p_us_resident_confirmed is distinct from true then
    raise exception 'LEGAL_CONFIRMATIONS_REQUIRED' using errcode = '22023';
  end if;

  insert into app.user_legal_acceptances (
    user_id,
    terms_version,
    privacy_version,
    community_guidelines_version,
    accepted_locale,
    adult_confirmed,
    us_resident_confirmed
  ) values (
    v_user_id,
    '2026-10-28',
    '2026-10-28',
    '2026-10-28',
    p_accepted_locale,
    true,
    true
  )
  on conflict (
    user_id,
    terms_version,
    privacy_version,
    community_guidelines_version
  ) do nothing;

  select acceptance.accepted_at into v_accepted_at
  from app.user_legal_acceptances acceptance
  where acceptance.user_id = v_user_id
    and acceptance.terms_version = '2026-10-28'
    and acceptance.privacy_version = '2026-10-28'
    and acceptance.community_guidelines_version = '2026-10-28';

  return jsonb_build_object('acceptedAt', v_accepted_at);
end;
$$;

create or replace function api.get_admin_user_legal_acceptances(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;
  if not app.is_current_user_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(acceptance) - 'user_id' order by acceptance.accepted_at desc)
    from app.user_legal_acceptances acceptance
    where acceptance.user_id = p_user_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function api.get_current_user_legal_status() from public, anon;
revoke all on function api.accept_current_user_legal_documents(text, boolean, boolean) from public, anon;
revoke all on function api.get_admin_user_legal_acceptances(uuid) from public, anon;

grant execute on function api.get_current_user_legal_status() to authenticated, service_role;
grant execute on function api.accept_current_user_legal_documents(text, boolean, boolean) to authenticated, service_role;
grant execute on function api.get_admin_user_legal_acceptances(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';
