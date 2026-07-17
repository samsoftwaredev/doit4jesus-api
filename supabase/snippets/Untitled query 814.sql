CREATE TABLE competition.challenge_definitions (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  code VARCHAR(100) NOT NULL UNIQUE,

  title VARCHAR(150) NOT NULL,

  description TEXT,

  

  challenge_type TEXT NOT NULL

    CHECK (challenge_type IN (

      'daily',

      'weekly',

      'special',

      'seasonal'

    )),

  

  activity_code VARCHAR(50)

    REFERENCES competition.activity_definitions(code),

  

  target_quantity INTEGER NOT NULL DEFAULT 1

    CHECK (target_quantity > 0),

  

  xp_reward INTEGER NOT NULL DEFAULT 0

    CHECK (xp_reward >= 0),

  

  badge_reward_id UUID,

  

  difficulty TEXT NOT NULL DEFAULT 'normal'

    CHECK (difficulty IN (

      'easy',

      'normal',

      'hard',

      'heroic'

    )),

  

  assignment_weight INTEGER NOT NULL DEFAULT 100

    CHECK (assignment_weight >= 0),

  

  rules JSONB NOT NULL DEFAULT '{}'::JSONB,

  

  icon_url TEXT,

  

  starts_at TIMESTAMPTZ,

  ends_at TIMESTAMPTZ,

  

  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  CHECK (

    ends_at IS NULL

    OR starts_at IS NULL

    OR ends_at > starts_at

  )

);

  

CREATE INDEX idx_challenge_definitions_active_type

  ON competition.challenge_definitions(

    challenge_type,

    is_active

  );

  

CREATE INDEX idx_challenge_definitions_rules

  ON competition.challenge_definitions

  USING GIN(rules);

  

CREATE TRIGGER trg_challenge_definitions_updated_at

BEFORE UPDATE ON competition.challenge_definitions

FOR EACH ROW

EXECUTE FUNCTION platform.set_updated_at();
