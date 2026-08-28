-- Country and city autocomplete backed by the Countries States Cities
-- Database. The import itself is an administrative job because the pinned
-- catalog contains more than 150,000 cities and should not bloat migrations.

create extension if not exists pg_trgm with schema extensions;

alter table app.cities
add column if not exists source_id bigint;

alter table app.cities
add column if not exists updated_at timestamptz not null default now();

-- The upstream catalog contains distinct places with the same country, state,
-- and city name. Its stable numeric city ID is therefore the sync key.
alter table app.cities
drop constraint if exists cities_country_code_name_region_name_key;

create unique index if not exists cities_source_id_key
on app.cities (source_id);

alter table app.cities
drop constraint if exists cities_source_id_positive;

alter table app.cities
add constraint cities_source_id_positive
check (source_id is null or source_id > 0);

-- Preserve UUIDs already referenced by seeded profiles and activity records.
update app.cities
set source_id = case
  when country_code = 'US' and name = 'Austin' and region_name = 'Texas' then 111668
  when country_code = 'US' and name = 'Dallas' and region_name = 'Texas' then 114990
  when country_code = 'MX' and name = 'Mexico City' then 72102
  else source_id
end
where source_id is null;

drop trigger if exists trg_cities_updated_at on app.cities;
create trigger trg_cities_updated_at
before update on app.cities
for each row execute function platform.set_updated_at();

create index if not exists countries_name_search_trgm
on app.countries
using gin (lower(name) extensions.gin_trgm_ops)
where is_active;

create index if not exists cities_name_search_trgm
on app.cities
using gin (lower(name) extensions.gin_trgm_ops)
where is_active;

grant select, insert, update on app.countries, app.cities to service_role;

create or replace function api.search_countries(
  p_query text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  code char(2),
  name varchar,
  latitude numeric,
  longitude numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(lower(trim(p_query)), '');
  v_pattern text;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if p_query is not null and (v_query is null or char_length(v_query) > 120) then
    raise exception 'INVALID_LOCATION_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  v_pattern := replace(
    replace(
      replace(coalesce(v_query, ''), chr(92), chr(92) || chr(92)),
      '%',
      chr(92) || '%'
    ),
    '_',
    chr(92) || '_'
  );

  return query
  select
    country.code,
    country.name,
    country.latitude,
    country.longitude
  from app.countries country
  where country.is_active
    and (
      v_query is null
      or lower(country.code::text) = v_query
      or lower(country.name) like '%' || v_pattern || '%' escape chr(92)
    )
  order by
    case
      when v_query is null then 0
      when lower(country.code::text) = v_query then 0
      when lower(country.name) = v_query then 0
      when strpos(lower(country.name), v_query) = 1 then 1
      else 2
    end,
    lower(country.name),
    country.code
  limit greatest(1, least(coalesce(p_limit, 20), 101))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function api.search_cities(
  p_country_code text,
  p_query text,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  name varchar,
  region_name varchar,
  country_code char(2),
  timezone varchar,
  latitude numeric,
  longitude numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_country_code text := upper(trim(p_country_code));
  v_query text := lower(trim(p_query));
  v_pattern text;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'P0001';
  end if;

  if v_country_code is null
    or v_country_code !~ '^[A-Z]{2}$'
    or v_query is null
    or char_length(v_query) < 2
    or char_length(v_query) > 150 then
    raise exception 'INVALID_LOCATION_SEARCH_QUERY' using errcode = 'P0001';
  end if;

  v_pattern := replace(
    replace(
      replace(v_query, chr(92), chr(92) || chr(92)),
      '%',
      chr(92) || '%'
    ),
    '_',
    chr(92) || '_'
  );

  return query
  select
    city.id,
    city.name,
    city.region_name,
    city.country_code,
    city.timezone,
    city.latitude,
    city.longitude
  from app.cities city
  where city.is_active
    and city.country_code = v_country_code::char(2)
    and lower(city.name) like '%' || v_pattern || '%' escape chr(92)
  order by
    case
      when lower(city.name) = v_query then 0
      when strpos(lower(city.name), v_query) = 1 then 1
      else 2
    end,
    lower(city.name),
    lower(coalesce(city.region_name, '')),
    city.source_id nulls last,
    city.id
  limit greatest(1, least(coalesce(p_limit, 20), 101))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function api.search_countries(text, integer, integer)
from public, anon;
revoke all on function api.search_cities(text, text, integer, integer)
from public, anon;

grant execute on function api.search_countries(text, integer, integer)
to authenticated, service_role;
grant execute on function api.search_cities(text, text, integer, integer)
to authenticated, service_role;
