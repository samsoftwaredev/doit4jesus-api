CREATE TABLE app.users (

 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

 email TEXT NOT NULL UNIQUE,

 password_hash TEXT,

  

 status TEXT NOT NULL DEFAULT 'active'

  CHECK (status IN (

   'pending',

   'active',

   'suspended',

   'deleted'

  )),

  

 email_verified_at TIMESTAMPTZ,

 last_login_at TIMESTAMPTZ,

  

 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

 deleted_at TIMESTAMPTZ

);

  

CREATE INDEX idx_users_status

 ON app.users(status)

 WHERE deleted_at IS NULL;

  
