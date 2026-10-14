-- Administrative email campaigns, test sends, and provider-event reporting.
-- All browser access remains administrator-only; Resend webhooks use service_role.

create table app.email_test_recipients (
  id uuid primary key default gen_random_uuid(),
  email public.citext not null unique,
  created_by uuid references app.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table app.email_campaigns (
  id uuid primary key default gen_random_uuid(),
  template_key text not null check (template_key in ('update', 'announcement')),
  subject text not null check (char_length(subject) between 1 and 160),
  content jsonb not null,
  rendered_html text not null,
  status text not null default 'draft' check (status in ('draft', 'scheduled', 'sent', 'cancelled', 'failed')),
  recipient_count integer not null default 0 check (recipient_count >= 0),
  resend_broadcast_id text unique,
  scheduled_for timestamptz,
  sent_at timestamptz,
  last_tested_revision text,
  created_by uuid references app.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'scheduled' and scheduled_for is not null and resend_broadcast_id is not null)
    or status <> 'scheduled'
  )
);

create table app.email_test_runs (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references app.email_campaigns(id) on delete cascade,
  revision text not null,
  recipient_count integer not null check (recipient_count > 0),
  accepted_count integer not null default 0 check (accepted_count >= 0),
  status text not null check (status in ('accepted', 'failed')),
  created_by uuid references app.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table app.email_sends (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid references app.email_campaigns(id) on delete cascade,
  test_run_id uuid references app.email_test_runs(id) on delete set null,
  contact_request_id uuid references app.contact_requests(id) on delete set null,
  kind text not null check (kind in ('campaign', 'test', 'reply')),
  recipient_email public.citext not null,
  resend_email_id text unique,
  resend_broadcast_id text,
  last_event text,
  sent_at timestamptz,
  delivered_at timestamptz,
  opened_at timestamptz,
  clicked_at timestamptz,
  bounced_at timestamptz,
  complained_at timestamptz,
  suppressed_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (kind = 'campaign' and campaign_id is not null)
    or (kind = 'test' and campaign_id is not null and test_run_id is not null)
    or (kind = 'reply' and contact_request_id is not null)
  )
);

create index email_campaigns_status_created_at_idx
  on app.email_campaigns (status, created_at desc);
create index email_sends_campaign_id_idx on app.email_sends (campaign_id);
create index email_sends_broadcast_id_idx on app.email_sends (resend_broadcast_id);
create index email_sends_contact_request_id_idx on app.email_sends (contact_request_id);

create table app.email_webhook_events (
  resend_event_id text primary key,
  event_type text not null,
  resend_email_id text,
  resend_broadcast_id text,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table app.email_suppressions (
  email public.citext primary key,
  reason text not null check (reason in ('unsubscribe', 'bounce', 'complaint', 'suppressed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_email_campaigns_updated_at
before update on app.email_campaigns
for each row execute function platform.set_updated_at();

create trigger trg_email_suppressions_updated_at
before update on app.email_suppressions
for each row execute function platform.set_updated_at();

alter table app.email_test_recipients enable row level security;
alter table app.email_campaigns enable row level security;
alter table app.email_test_runs enable row level security;
alter table app.email_sends enable row level security;
alter table app.email_webhook_events enable row level security;
alter table app.email_suppressions enable row level security;

grant select, insert, update, delete on app.email_test_recipients to authenticated;
grant select, insert, update, delete on app.email_campaigns to authenticated;
grant select, insert, update, delete on app.email_test_runs to authenticated;
grant select, insert, update, delete on app.email_sends to authenticated;
grant select on app.email_webhook_events to authenticated;
grant select on app.email_suppressions to authenticated;
grant all privileges on app.email_test_recipients, app.email_campaigns,
  app.email_test_runs, app.email_sends, app.email_webhook_events,
  app.email_suppressions to service_role;

create policy email_test_recipients_admin
on app.email_test_recipients for all to authenticated
using (app.is_current_user_admin()) with check (app.is_current_user_admin());

create policy email_campaigns_admin
on app.email_campaigns for all to authenticated
using (app.is_current_user_admin()) with check (app.is_current_user_admin());

create policy email_test_runs_admin
on app.email_test_runs for all to authenticated
using (app.is_current_user_admin()) with check (app.is_current_user_admin());

create policy email_sends_admin
on app.email_sends for all to authenticated
using (app.is_current_user_admin()) with check (app.is_current_user_admin());

create policy email_webhook_events_admin
on app.email_webhook_events for select to authenticated
using (app.is_current_user_admin());

create policy email_suppressions_admin
on app.email_suppressions for select to authenticated
using (app.is_current_user_admin());
