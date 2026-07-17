CREATE TABLE competition.point_rules (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  code VARCHAR(100) NOT NULL UNIQUE,

  

  activity_code VARCHAR(50)

    REFERENCES competition.activity_definitions(code),

  

  name VARCHAR(150) NOT NULL,

  description TEXT,

  

  points INTEGER NOT NULL

    CHECK (points >= 0),

  

  daily_limit INTEGER

    CHECK (

      daily_limit IS NULL

      OR daily_limit > 0

    ),

  

  weekly_limit INTEGER

    CHECK (

      weekly_limit IS NULL

      OR weekly_limit > 0

    ),

  

  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  effective_until TIMESTAMPTZ,

  

  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  CHECK (

    effective_until IS NULL

    OR effective_until > effective_from

  )

);

  

CREATE INDEX idx_point_rules_activity

  ON competition.point_rules(activity_code)

  WHERE is_active = TRUE;

  

CREATE TRIGGER trg_point_rules_updated_at

BEFORE UPDATE ON competition.point_rules

FOR EACH ROW

EXECUTE FUNCTION platform.set_updated_at();