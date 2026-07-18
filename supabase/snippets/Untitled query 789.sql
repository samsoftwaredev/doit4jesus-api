CREATE TABLE prayer.prayer_events (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  user_id UUID NOT NULL

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  activity_id UUID

    REFERENCES competition.spiritual_activities(id),

  

  prayer_type TEXT NOT NULL

    CHECK (prayer_type IN (

      'rosary',

      'divine_mercy',

      'scripture',

      'intercession',

      'adoration',

      'other'

    )),

  

  quantity INTEGER NOT NULL DEFAULT 1

    CHECK (quantity > 0),

  

  started_at TIMESTAMPTZ,

  completed_at TIMESTAMPTZ NOT NULL,

  

  city_id UUID

    REFERENCES app.cities(id),

  

  country_code CHAR(2) NOT NULL

    REFERENCES app.countries(code),

  

  visibility TEXT NOT NULL DEFAULT 'aggregated'

    CHECK (visibility IN (

      'aggregated',

      'private'

    )),

  

  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

  

CREATE INDEX idx_prayer_events_country_completed

  ON prayer.prayer_events(

    country_code,

    completed_at DESC

  );

  

CREATE INDEX idx_prayer_events_city_completed

  ON prayer.prayer_events(

    city_id,

    completed_at DESC

  )

  WHERE city_id IS NOT NULL;

  

CREATE INDEX idx_prayer_events_type_completed

  ON prayer.prayer_events(

    prayer_type,

    completed_at DESC

  );
