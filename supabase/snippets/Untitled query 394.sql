CREATE TABLE competition.spiritual_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL
    REFERENCES app.users(id)
    ON DELETE CASCADE,
  activity_code VARCHAR(50) NOT NULL
    REFERENCES competition.activity_definitions(code),
  occurred_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER
    CHECK (
      duration_seconds IS NULL
      OR duration_seconds >= 0
    ),
  quantity INTEGER NOT NULL DEFAULT 1
    CHECK (quantity > 0),
  verification_status TEXT NOT NULL DEFAULT 'self_reported'
    CHECK (verification_status IN (

      'self_reported',

      'verified',

      'rejected'

    )),

  

  source TEXT NOT NULL DEFAULT 'manual'
    CHECK (source IN (

      'manual',

      'challenge',

      'live_prayer',

      'import',

      'admin',

      'system'

    )),

  

  city_id UUID

    REFERENCES app.cities(id),

  

  country_code CHAR(2)

    REFERENCES app.countries(code),

  

  idempotency_key VARCHAR(150),

  

  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  UNIQUE (user_id, idempotency_key)

);