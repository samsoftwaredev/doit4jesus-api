CREATE TABLE prayer.country_daily_aggregates (

  country_code CHAR(2) NOT NULL

    REFERENCES app.countries(code),

  

  aggregate_date DATE NOT NULL,

  

  total_prayers BIGINT NOT NULL DEFAULT 0,

  unique_users BIGINT NOT NULL DEFAULT 0,

  rosaries BIGINT NOT NULL DEFAULT 0,

  prayer_duration_seconds BIGINT NOT NULL DEFAULT 0,

  

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  PRIMARY KEY (

    country_code,

    aggregate_date

  ),

  

  CHECK (total_prayers >= 0),

  CHECK (unique_users >= 0),

  CHECK (rosaries >= 0),

  CHECK (prayer_duration_seconds >= 0)

);

  

CREATE INDEX idx_country_aggregates_date_prayers

  ON prayer.country_daily_aggregates(

    aggregate_date,

    total_prayers DESC

  );
