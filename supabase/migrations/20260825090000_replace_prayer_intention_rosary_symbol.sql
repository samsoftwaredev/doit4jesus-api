-- Replace the prayer-intention artwork key with a more broadly applicable
-- symbol. Convert existing values before tightening the database constraint.

alter table prayer.prayer_intentions
  drop constraint prayer_intentions_symbol_check;

update prayer.prayer_intentions
set symbol = 'olive_branch'
where symbol = 'rosary';

alter table prayer.prayer_intentions
  add constraint prayer_intentions_symbol_check
  check (
    symbol is null
    or symbol in ('candle', 'cross', 'dove', 'olive_branch')
  );
