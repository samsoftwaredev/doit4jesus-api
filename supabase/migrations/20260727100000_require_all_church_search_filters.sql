-- Church discovery is intentionally scoped to one precise locality. All three
-- filters are required and must match the same approved church.

create or replace function api.search_churches(
  p_country_code text default null,
  p_city text default null,
  p_diocese text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  name varchar,
  city varchar,
  region_name varchar,
  country_code char(2),
  diocese_name varchar,
  timezone varchar
)
language sql
stable
set search_path = ''
as $$
  select
    church_record.id,
    church_record.name,
    church_record.city,
    church_record.region_name,
    church_record.country_code,
    diocese_record.name as diocese_name,
    church_record.timezone
  from app.churches church_record
  join app.dioceses diocese_record
    on diocese_record.id = church_record.diocese_id
  where church_record.is_active
    and church_record.country_code = upper(trim(p_country_code))::char(2)
    and lower(church_record.city) = lower(trim(p_city))
    and lower(diocese_record.name) = lower(trim(p_diocese))
  order by church_record.name, church_record.id
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function api.search_churches(text, text, text, integer, integer)
to authenticated, service_role;
