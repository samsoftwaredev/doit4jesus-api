-- Physical event addresses use the same supported ISO-country catalogue as
-- church addresses, while remaining separate from profile location data.

alter table app.events
  add constraint events_country_code_fkey
  foreign key (country_code)
  references app.countries(code);
