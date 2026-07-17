CREATE TABLE competition.level_definitions (
  level_number INTEGER PRIMARY KEY
    CHECK (level_number > 0),
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  minimum_total_xp BIGINT NOT NULL UNIQUE
    CHECK (minimum_total_xp >= 0),
  icon_url TEXT,
  image_url TEXT,
  reward_type VARCHAR(50),
  reward_reference_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);