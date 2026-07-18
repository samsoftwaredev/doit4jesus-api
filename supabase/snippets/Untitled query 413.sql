CREATE TABLE platform.outbox_events (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  aggregate_type VARCHAR(100) NOT NULL,

  aggregate_id UUID NOT NULL,

  

  event_type VARCHAR(150) NOT NULL,

  payload JSONB NOT NULL,

  

  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  processing_status TEXT NOT NULL DEFAULT 'pending'

    CHECK (processing_status IN (

      'pending',

      'processing',

      'processed',

      'failed'

    )),

  

  attempt_count INTEGER NOT NULL DEFAULT 0

    CHECK (attempt_count >= 0),

  

  available_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  locked_at TIMESTAMPTZ,

  processed_at TIMESTAMPTZ,

  

  last_error TEXT

);

  

CREATE INDEX idx_outbox_pending

  ON platform.outbox_events(

    available_at,

    occurred_at

  )

  WHERE processing_status IN ('pending', 'failed');