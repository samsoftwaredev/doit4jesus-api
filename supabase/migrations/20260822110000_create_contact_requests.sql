-- Public contact-form submissions are written only by the server route using
-- the service role. There is intentionally no client read access because the
-- rows contain contact details and support messages.

create table app.contact_requests (
  id uuid primary key default gen_random_uuid(),
  name varchar(120) not null,
  email varchar(320) not null,
  subject varchar(100) not null,
  other_subject varchar(120),
  message text not null,
  created_at timestamptz not null default now(),
  constraint contact_requests_name_not_blank check (length(trim(name)) > 0),
  constraint contact_requests_email_not_blank check (length(trim(email)) > 0),
  constraint contact_requests_message_not_blank check (length(trim(message)) > 0),
  constraint contact_requests_subject_check check (subject in (
    'Billing & Payments',
    'Subscription Management',
    'Login & Account Access',
    'App Performance & Bugs',
    'Audio & Playback Issues',
    'Streak & Progress Issues',
    'Content Feedback & Requests',
    'Prayer Intentions',
    'Grammar & Audio Mistakes',
    'Parish & Church Programs',
    'School & Ministry Licensing',
    'Media & Press Inquiries',
    'Other'
  )),
  constraint contact_requests_other_subject_check check (
    (subject = 'Other' and other_subject is not null and length(trim(other_subject)) > 0)
    or (subject <> 'Other' and other_subject is null)
  )
);

create index contact_requests_created_at_desc_idx
  on app.contact_requests (created_at desc);

alter table app.contact_requests enable row level security;

revoke all on table app.contact_requests from anon, authenticated;
