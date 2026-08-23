create table app.examination_of_conscience_questions (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('single', 'married', 'religious')),
  title varchar(120) not null check (length(trim(title)) > 0),
  commandment smallint not null check (commandment between 1 and 10),
  severity text not null check (severity in ('mortal', 'grave')),
  question text not null check (length(trim(question)) > 0),
  description text not null check (length(trim(description)) > 0),
  counsels text[] not null check (cardinality(counsels) > 0),
  prevention text[] not null check (cardinality(prevention) > 0),
  saints text[] not null check (cardinality(saints) > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint examination_of_conscience_questions_question_key unique (question)
);

create index examination_of_conscience_questions_daily_lookup_idx
  on app.examination_of_conscience_questions (is_active, category, commandment, severity);
create index examination_of_conscience_questions_saints_idx
  on app.examination_of_conscience_questions using gin (saints);

create trigger trg_examination_of_conscience_questions_updated_at
before update on app.examination_of_conscience_questions
for each row execute function platform.set_updated_at();

alter table app.examination_of_conscience_questions enable row level security;
revoke all on app.examination_of_conscience_questions from anon;
grant select, insert, update, delete on app.examination_of_conscience_questions to authenticated;
grant all privileges on app.examination_of_conscience_questions to service_role;

create policy examination_of_conscience_questions_admin_manage
on app.examination_of_conscience_questions
for all to authenticated
using (app.is_current_user_admin())
with check (app.is_current_user_admin());
