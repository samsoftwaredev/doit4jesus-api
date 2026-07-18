CREATE TABLE competition.badge_shares (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  user_badge_id UUID NOT NULL

    REFERENCES competition.user_badges(id)

    ON DELETE CASCADE,

  

  share_token VARCHAR(120) NOT NULL UNIQUE,

  

  platform TEXT

    CHECK (platform IN (

      'copy_link',

      'facebook',

      'instagram',

      'x',

      'whatsapp',

      'other'

    )),

  

  visibility TEXT NOT NULL DEFAULT 'public'

    CHECK (visibility IN (

      'public',

      'unlisted',

      'private'

    )),

  

  expires_at TIMESTAMPTZ,

  revoked_at TIMESTAMPTZ,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

  

CREATE INDEX idx_badge_shares_active_token

  ON competition.badge_shares(share_token)

  WHERE revoked_at IS NULL;