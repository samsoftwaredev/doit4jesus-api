CREATE TABLE competition.point_ledger (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL
    REFERENCES app.users(id)
    ON DELETE CASCADE,
  point_rule_id UUID
    REFERENCES competition.point_rules(id),
  activity_id UUID
    REFERENCES competition.spiritual_activities(id),
  source_type VARCHAR(50) NOT NULL,
  source_id UUID,
  transaction_type TEXT NOT NULL
    CHECK (transaction_type IN (

      'award',

      'reversal',

      'adjustment'

    )),
  points INTEGER NOT NULL

    CHECK (points <> 0),
  reason VARCHAR(150) NOT NULL,
  idempotency_key VARCHAR(150) NOT NULL UNIQUE,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);
CREATE INDEX idx_point_ledger_user_date

  ON competition.point_ledger (

    user_id,

    occurred_at DESC

  );
CREATE INDEX idx_point_ledger_activity

  ON competition.point_ledger(activity_id);
CREATE INDEX idx_point_ledger_source

  ON competition.point_ledger (

    source_type,

    source_id

  );