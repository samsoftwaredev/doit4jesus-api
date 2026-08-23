-- The public API serves only active questions. Management remains restricted
-- to administrators by the existing authenticated policy.

grant usage on schema app to anon;
grant select on app.examination_of_conscience_questions to anon;

create policy examination_of_conscience_questions_public_read_active
on app.examination_of_conscience_questions
for select to anon, authenticated
using (is_active);
