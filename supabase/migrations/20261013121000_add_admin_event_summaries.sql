-- Keep attendee and unique-view totals available to administrators without
-- granting direct access to either participant ledger.

create view app.admin_event_summaries
with (security_barrier = true)
as
select
  event_record.id,
  event_record.creator_id,
  event_record.title,
  event_record.description,
  event_record.image_url,
  event_record.event_url,
  event_record.event_type,
  event_record.online_url,
  event_record.location_name,
  event_record.address_line_1,
  event_record.address_line_2,
  event_record.city,
  event_record.region_name,
  event_record.postal_code,
  event_record.country_code,
  event_record.timezone,
  event_record.starts_at,
  event_record.ends_at,
  event_record.lifespan_days,
  event_record.audiences,
  event_record.status,
  event_record.reviewed_by,
  event_record.reviewed_at,
  event_record.created_at,
  event_record.reviewed_at + make_interval(days => event_record.lifespan_days) as expires_at,
  (select count(*)::integer from app.event_attendees attendee where attendee.event_id = event_record.id) as attendee_count,
  (select count(*)::integer from app.event_views event_view where event_view.event_id = event_record.id) as view_count
from app.events event_record
where app.is_current_user_admin();

revoke all privileges on table app.admin_event_summaries from anon, authenticated;
grant select on table app.admin_event_summaries to authenticated, service_role;
