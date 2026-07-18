CREATE TABLE competition.user_badges (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  user_id UUID NOT NULL

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  badge_id UUID NOT NULL

    REFERENCES competition.badge_definitions(id),

  

  earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  source_type VARCHAR(50),

  source_id UUID,

  

  sequence_number INTEGER NOT NULL DEFAULT 1

    CHECK (sequence_number > 0),

  

  is_featured BOOLEAN NOT NULL DEFAULT FALSE,

  

  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

  

  UNIQUE (

    user_id,

    badge_id,

    sequence_number

  )

);

  

CREATE INDEX idx_user_badges_user_earned

  ON competition.user_badges(

    user_id,

    earned_at DESC

  );

  

CREATE INDEX idx_user_badges_featured

  ON competition.user_badges(user_id)

  WHERE is_featured = TRUE;

  