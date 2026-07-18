CREATE TABLE competition.leaderboard_periods (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  period_type TEXT NOT NULL

    CHECK (period_type IN (

      'daily',

      'weekly',

      'monthly',

      'yearly',

      'season'

    )),

  

  code VARCHAR(100) NOT NULL UNIQUE,

  name VARCHAR(150) NOT NULL,

  

  starts_at TIMESTAMPTZ NOT NULL,

  ends_at TIMESTAMPTZ NOT NULL,

  

  status TEXT NOT NULL DEFAULT 'scheduled'

    CHECK (status IN (

      'scheduled',

      'active',

      'calculating',

      'finalized'

    )),

  

  finalized_at TIMESTAMPTZ,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  CHECK (ends_at > starts_at)

);

  

CREATE INDEX idx_leaderboard_periods_type_status

  ON competition.leaderboard_periods(

    period_type,

    status,

    starts_at DESC

  );
