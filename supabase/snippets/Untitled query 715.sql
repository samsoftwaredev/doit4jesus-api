CREATE TABLE competition.user_badge_progress (

  user_id UUID NOT NULL

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  badge_id UUID NOT NULL

    REFERENCES competition.badge_definitions(id)

    ON DELETE CASCADE,

  

  current_value INTEGER NOT NULL DEFAULT 0

    CHECK (current_value >= 0),

  

  required_value INTEGER NOT NULL

    CHECK (required_value > 0),

  

  progress_percentage NUMERIC(5, 2) GENERATED ALWAYS AS (

    LEAST(

      100.00,

      current_value::NUMERIC

      / required_value::NUMERIC

      * 100

    )

  ) STORED,

  

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  PRIMARY KEY (

    user_id,

    badge_id

  )

);