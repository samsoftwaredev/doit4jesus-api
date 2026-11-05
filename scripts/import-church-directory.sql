\set ECHO errors
\pset pager off

begin;
set local lock_timeout = '10s';
set local statement_timeout = '15min';

create temporary table postal_source (
  zip_code text, city text, city_label text, city_geoid text, city_state text,
  city_overlap_percent text, city_status text, latitude text, longitude text,
  centroid_county text, centroid_state text, diocese text,
  candidate_dioceses text, diocese_status text, timezone text,
  timezone_candidates text, timezone_status text, zcta_source_year text,
  city_source_year text, diocese_source_year text,
  timezone_source_release text
) on commit drop;

create temporary table church_source (
  church_id text, church_name text, church_address text, street_address text,
  city text, state text, zip_code text, diocese text, latitude text,
  longitude text, diocese_status text, record_status text,
  review_reasons text, source text, source_id text, source_release text,
  source_category text, source_confidence text
) on commit drop;

\copy pg_temp.postal_source from __POSTAL_CSV__ with (format csv, header true)
\copy pg_temp.church_source from __CHURCHES_CSV__ with (format csv, header true)

do $$
begin
  if (select count(*) from postal_source) <> 57918 then
    raise exception 'CHURCH_DIRECTORY_INVALID_POSTAL_ROW_COUNT';
  end if;
  if (select count(*) from church_source) <> 24145 then
    raise exception 'CHURCH_DIRECTORY_INVALID_CHURCH_ROW_COUNT';
  end if;
  if (select count(*) from church_source where record_status = 'geographically_assigned_unverified') <> 17497 then
    raise exception 'CHURCH_DIRECTORY_INVALID_ELIGIBLE_CHURCH_COUNT';
  end if;
  if (select count(distinct zip_code) from postal_source) <> 33653 then
    raise exception 'CHURCH_DIRECTORY_INVALID_UNIQUE_POSTAL_COUNT';
  end if;
  if exists (
    select 1 from postal_source
    where zip_code !~ '^[0-9]{5}$' or timezone = '' or latitude = '' or longitude = ''
  ) then
    raise exception 'CHURCH_DIRECTORY_INVALID_POSTAL_DATA';
  end if;
end;
$$;

insert into app.dioceses (country_code, name)
select distinct
  case when source.state = 'VI' then 'VI' else 'US' end::char(2),
  btrim(source.diocese)
from church_source source
where source.record_status = 'geographically_assigned_unverified'
  and btrim(source.diocese) <> ''
on conflict (country_code, name) do nothing;

with ranked as (
  select
    source.*,
    row_number() over (
      partition by source.zip_code
      order by nullif(source.city_overlap_percent, '')::numeric desc nulls last,
        (nullif(source.city, '') is not null) desc, source.city
    ) as row_number
  from postal_source source
), regions as (
  select source.zip_code,
    array_agg(distinct region order by region) filter (where region <> '') as region_codes
  from postal_source source
  cross join lateral regexp_split_to_table(
    concat_ws(';', nullif(source.centroid_state, ''), nullif(source.city_state, '')),
    ';'
  ) region
  group by source.zip_code
)
insert into app.postal_codes (
  postal_code, primary_city, region_codes, latitude, longitude, timezone,
  diocese_status, zcta_source_year, city_source_year, diocese_source_year,
  timezone_source_release, imported_at
)
select
  ranked.zip_code,
  nullif(ranked.city, ''),
  coalesce(regions.region_codes, '{}'::text[]),
  ranked.latitude::numeric,
  ranked.longitude::numeric,
  ranked.timezone,
  ranked.diocese_status,
  ranked.zcta_source_year::integer,
  ranked.city_source_year::integer,
  ranked.diocese_source_year::integer,
  ranked.timezone_source_release,
  now()
from ranked
join regions using (zip_code)
where ranked.row_number = 1
on conflict (postal_code) do update set
  primary_city = excluded.primary_city,
  region_codes = excluded.region_codes,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  timezone = excluded.timezone,
  diocese_status = excluded.diocese_status,
  zcta_source_year = excluded.zcta_source_year,
  city_source_year = excluded.city_source_year,
  diocese_source_year = excluded.diocese_source_year,
  timezone_source_release = excluded.timezone_source_release,
  imported_at = now();

with ranked as (
  select source.*,
    row_number() over (
      partition by source.zip_code
      order by nullif(source.city_overlap_percent, '')::numeric desc nulls last,
        source.city
    ) as postal_rank,
    row_number() over (
      partition by source.zip_code, source.city, coalesce(source.city_state, '')
      order by nullif(source.city_overlap_percent, '')::numeric desc nulls last,
        source.city_geoid
    ) as duplicate_rank
  from postal_source source
  where source.city <> ''
)
insert into app.postal_code_cities (
  postal_code, city_name, city_label, city_geoid, region_code,
  overlap_percent, city_status, is_primary
)
select zip_code, city, nullif(city_label, ''), nullif(city_geoid, ''),
  coalesce(city_state, ''), nullif(city_overlap_percent, '')::numeric,
  city_status, postal_rank = 1
from ranked
where duplicate_rank = 1
on conflict (postal_code, city_name, region_code) do update set
  city_label = excluded.city_label,
  city_geoid = excluded.city_geoid,
  overlap_percent = excluded.overlap_percent,
  city_status = excluded.city_status,
  is_primary = excluded.is_primary;

with postal_labels as (
  select distinct source.zip_code as postal_code, btrim(split.label) as label, source.diocese_status
  from postal_source source
  cross join lateral regexp_split_to_table(
    case when source.diocese <> '' then source.diocese else source.candidate_dioceses end,
    ';'
  ) as split(label)
  where btrim(split.label) <> ''
), matched as (
  select postal_label.*,
    (
      select diocese.id from app.dioceses diocese
      where diocese.search_key = app.normalize_diocese_name(postal_label.label)
      order by case when diocese.country_code = 'US' then 0 else 1 end, diocese.name
      limit 1
    ) as diocese_id
  from postal_labels postal_label
)
insert into app.postal_code_dioceses (postal_code, diocese_id, label, match_status)
select matched.postal_code, matched.diocese_id, matched.label,
  case when matched.diocese_id is null then 'unresolved' else matched.diocese_status end
from matched matched
on conflict (postal_code, label) do update set
  diocese_id = excluded.diocese_id,
  match_status = excluded.match_status;

with eligible as (
  select
    source.*,
    row_number() over (
      partition by lower(btrim(source.church_name)), lower(btrim(source.street_address)), source.zip_code
      order by nullif(source.source_confidence, '')::numeric desc nulls last, source.source_id
    ) as duplicate_rank
  from church_source source
  join app.postal_codes postal on postal.postal_code = source.zip_code
  where source.record_status = 'geographically_assigned_unverified'
), prepared as (
  select
    eligible.*,
    case when eligible.state = 'VI' then 'VI' else 'US' end::char(2) as country_code,
    postal.timezone,
    diocese.id as diocese_id
  from eligible
  join app.postal_codes postal on postal.postal_code = eligible.zip_code
  left join app.dioceses diocese
    on diocese.country_code = case when eligible.state = 'VI' then 'VI' else 'US' end::char(2)
    and diocese.name = eligible.diocese
  where eligible.duplicate_rank = 1
)
insert into app.churches (
  diocese_id, name, address_line_1, city, region_name, postal_code,
  country_code, timezone, latitude, longitude, is_active, source, source_id,
  source_release, source_confidence, directory_verification_status
)
select
  prepared.diocese_id, btrim(prepared.church_name), btrim(prepared.street_address),
  btrim(prepared.city), nullif(btrim(prepared.state), ''), prepared.zip_code,
  prepared.country_code, prepared.timezone, prepared.latitude::numeric,
  prepared.longitude::numeric, true, prepared.source, prepared.source_id,
  prepared.source_release, nullif(prepared.source_confidence, '')::numeric,
  'candidate'
from prepared
on conflict (source, source_id) where source is not null and source_id is not null
do update set
  diocese_id = excluded.diocese_id,
  name = excluded.name,
  address_line_1 = excluded.address_line_1,
  city = excluded.city,
  region_name = excluded.region_name,
  postal_code = excluded.postal_code,
  country_code = excluded.country_code,
  timezone = excluded.timezone,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  source_release = excluded.source_release,
  source_confidence = excluded.source_confidence
where app.churches.directory_verification_status = 'candidate';

do $$
declare
  v_importable_churches integer;
begin
  select count(*) into v_importable_churches
  from (
    select 1
    from church_source source
    join app.postal_codes postal on postal.postal_code = source.zip_code
    where source.record_status = 'geographically_assigned_unverified'
    group by lower(btrim(source.church_name)), lower(btrim(source.street_address)), source.zip_code
  ) importable;
  if v_importable_churches <> 17463 then
    raise exception 'CHURCH_DIRECTORY_INVALID_IMPORTABLE_COUNT: %', v_importable_churches;
  end if;
  raise notice 'Postal codes staged: %, church candidates importable: %',
    (select count(distinct zip_code) from postal_source), v_importable_churches;
end;
$$;

__FINALIZE__
