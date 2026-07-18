CREATE TABLE competition.user_metric_snapshots (

  user_id UUID NOT NULL

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  snapshot_date DATE NOT NULL,

  

  rosaries_count INTEGER NOT NULL DEFAULT 0,

  scripture_readings_count INTEGER NOT NULL DEFAULT 0,

  prayer_sessions_count INTEGER NOT NULL DEFAULT 0,

  service_acts_count INTEGER NOT NULL DEFAULT 0,

  

  points_earned INTEGER NOT NULL DEFAULT 0,

  

  prayer_duration_seconds BIGINT NOT NULL DEFAULT 0,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  PRIMARY KEY (

    user_id,

    snapshot_date

  ),

  

  CHECK (rosaries_count >= 0),

  CHECK (scripture_readings_count >= 0),

  CHECK (prayer_sessions_count >= 0),

  CHECK (service_acts_count >= 0),

  CHECK (points_earned >= 0),

  CHECK (prayer_duration_seconds >= 0)

);

  

CREATE INDEX idx_metric_snapshots_date

  ON competition.user_metric_snapshots(snapshot_date DESC);

  