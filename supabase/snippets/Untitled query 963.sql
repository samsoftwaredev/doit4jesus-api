CREATE TABLE competition.badge_definitions (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  code VARCHAR(100) NOT NULL UNIQUE,

  name VARCHAR(120) NOT NULL,

  description TEXT,

  

  category TEXT NOT NULL

    CHECK (category IN (

      'prayer',

      'scripture',

      'service',

      'discipline',

      'community',

      'achievement',

      'seasonal'

    )),

  

  rarity TEXT NOT NULL DEFAULT 'common'

    CHECK (rarity IN (

      'common',

      'uncommon',

      'rare',

      'epic',

      'legendary'

    )),

  

  icon_url TEXT NOT NULL,

  locked_icon_url TEXT,

  

  requirement_type VARCHAR(100),

  requirement_value INTEGER,

  

  rules JSONB NOT NULL DEFAULT '{}'::JSONB,

  

  points_reward INTEGER NOT NULL DEFAULT 0

    CHECK (points_reward >= 0),

  

  is_repeatable BOOLEAN NOT NULL DEFAULT FALSE,

  is_shareable BOOLEAN NOT NULL DEFAULT TRUE,

  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

  

CREATE INDEX idx_badge_definitions_category

  ON competition.badge_definitions(category)

  WHERE is_active = TRUE;

  

CREATE INDEX idx_badge_definitions_rules

  ON competition.badge_definitions

  USING GIN(rules);

  

CREATE TRIGGER trg_badge_definitions_updated_at

BEFORE UPDATE ON competition.badge_definitions

FOR EACH ROW

EXECUTE FUNCTION platform.set_updated_at();