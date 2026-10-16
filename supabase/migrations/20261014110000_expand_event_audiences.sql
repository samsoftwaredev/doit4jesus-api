-- Preserve existing event audiences while allowing additional pastoral groups.
alter table app.events
  drop constraint events_audiences_check;

alter table app.events
  add constraint events_audiences_check
  check (
    cardinality(audiences) between 1 and 3
    and audiences <@ array[
      'all', 'kids', 'youth', 'men', 'women', 'single', 'married'
    ]::text[]
  );
