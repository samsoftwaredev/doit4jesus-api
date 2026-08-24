-- Contact requests can be submitted without an account, but their contact
-- details must remain visible and manageable only to application admins.

alter table app.contact_requests
  add column status varchar(16) not null default 'todo',
  add constraint contact_requests_status_check
    check (status in ('todo', 'inprogress', 'done'));

-- The public submission form needs schema access and permission to insert only
-- the fields it owns. In particular, it cannot set the workflow status.
grant usage on schema app to anon;
grant insert (name, email, subject, other_subject, message)
  on app.contact_requests to anon, authenticated;

-- Direct reads and workflow management require an authenticated application
-- administrator. service_role remains available to trusted server processes.
grant select, update, delete on app.contact_requests to authenticated;
grant all privileges on app.contact_requests to service_role;

create policy contact_requests_submit
on app.contact_requests
for insert
to anon, authenticated
with check (status = 'todo');

create policy contact_requests_admin_manage
on app.contact_requests
for all
to authenticated
using (app.is_current_user_admin())
with check (app.is_current_user_admin());
