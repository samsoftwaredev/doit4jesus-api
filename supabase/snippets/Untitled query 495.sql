CREATE TABLE competition.leaderboard_entries (

  period_id UUID NOT NULL

    REFERENCES competition.leaderboard_periods(id)

    ON DELETE CASCADE,

  

  user_id UUID NOT NULL

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  scope_type TEXT NOT NULL

    CHECK (scope_type IN (

      'global',

      'country'

    )),

  

  scope_reference VARCHAR(150) NOT NULL DEFAULT 'global',

  

  points BIGINT NOT NULL DEFAULT 0

    CHECK (points >= 0),

  

  rank INTEGER

    CHECK (

      rank IS NULL

      OR rank > 0

    ),

  

  rosaries_count INTEGER NOT NULL DEFAULT 0

    CHECK (rosaries_count >= 0),

  

  scripture_readings_count INTEGER NOT NULL DEFAULT 0

    CHECK (scripture_readings_count >= 0),

  

  prayers_count INTEGER NOT NULL DEFAULT 0

    CHECK (prayers_count >= 0),

  

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  PRIMARY KEY (

    period_id,

    user_id,

    scope_type,

    scope_reference

  )

);

  

CREATE INDEX idx_leaderboard_entries_ranking

  ON competition.leaderboard_entries(

    period_id,

    scope_type,

    scope_reference,

    points DESC,

    user_id

  );

  

CREATE INDEX idx_leaderboard_entries_rank

  ON competition.leaderboard_entries(

    period_id,

    scope_type,

    scope_reference,

    rank

  );
