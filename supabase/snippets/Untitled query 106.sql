CREATE TABLE app.notifications (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  user_id UUID NOT NULL

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  notification_type VARCHAR(100) NOT NULL,

  title VARCHAR(200) NOT NULL,

  body TEXT,

  

  action_url TEXT,

  

  payload JSONB NOT NULL DEFAULT '{}'::JSONB,

  

  read_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

  

CREATE INDEX idx_notifications_user_unread

  ON app.notifications(

    user_id,

    created_at DESC

  )

  WHERE read_at IS NULL;
