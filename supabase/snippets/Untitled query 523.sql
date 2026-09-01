CREATE TABLE prayer.map_markers (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  aggregation_level TEXT NOT NULL

    CHECK (aggregation_level IN (

      'country'

    )),

  

  location_reference VARCHAR(150) NOT NULL,

  

  name VARCHAR(150) NOT NULL,

  country_code CHAR(2) NOT NULL,

  

  latitude NUMERIC(9, 6) NOT NULL,

  longitude NUMERIC(9, 6) NOT NULL,

  

  prayer_count BIGINT NOT NULL DEFAULT 0

    CHECK (prayer_count >= 0),

  

  unique_users BIGINT NOT NULL DEFAULT 0

    CHECK (unique_users >= 0),

  

  intensity NUMERIC(5, 4) NOT NULL DEFAULT 0

    CHECK (

      intensity >= 0

      AND intensity <= 1

    ),

  

  period_start TIMESTAMPTZ NOT NULL,

  period_end TIMESTAMPTZ NOT NULL,

  

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  UNIQUE (

    aggregation_level,

    location_reference,

    period_start,

    period_end

  )

);

  

CREATE INDEX idx_map_markers_period

  ON prayer.map_markers(

    aggregation_level,

    period_start,

    period_end

  );
