CREATE TABLE platform.idempotency_records (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  user_id UUID

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  idempotency_key VARCHAR(150) NOT NULL,

  request_method VARCHAR(10) NOT NULL,

  request_path TEXT NOT NULL,

  

  request_hash VARCHAR(128) NOT NULL,

  

  response_status INTEGER,

  response_body JSONB,

  

  locked_until TIMESTAMPTZ,

  completed_at TIMESTAMPTZ,

  

  expires_at TIMESTAMPTZ NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  UNIQUE (

    user_id,

    idempotency_key

  )

);

  

CREATE INDEX idx_idempotency_expiration

  ON platform.idempotency_records(expires_at);