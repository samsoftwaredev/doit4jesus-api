CREATE TABLE competition.user_challenge_assignments (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  user_id UUID NOT NULL

    REFERENCES app.users(id)

    ON DELETE CASCADE,

  

  challenge_definition_id UUID NOT NULL

    REFERENCES competition.challenge_definitions(id),

  

  assignment_date DATE NOT NULL,

  

  starts_at TIMESTAMPTZ NOT NULL,

  expires_at TIMESTAMPTZ NOT NULL,

  

  target_quantity INTEGER NOT NULL

    CHECK (target_quantity > 0),

  

  current_progress INTEGER NOT NULL DEFAULT 0

    CHECK (current_progress >= 0),

  

  status TEXT NOT NULL DEFAULT 'active'

    CHECK (status IN (

      'active',

      'completed',

      'expired',

      'cancelled'

    )),

  

  completed_at TIMESTAMPTZ,

  reward_claimed_at TIMESTAMPTZ,

  

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  UNIQUE (

    user_id,

    challenge_definition_id,

    assignment_date

  ),

  

  CHECK (expires_at > starts_at),

  CHECK (current_progress <= target_quantity)

);

  

CREATE INDEX idx_challenge_assignments_user_status

  ON competition.user_challenge_assignments(

    user_id,

    status,

    assignment_date DESC

  );

  

CREATE INDEX idx_challenge_assignments_expiration

  ON competition.user_challenge_assignments(expires_at)

  WHERE status = 'active';

  

CREATE TRIGGER trg_user_challenge_assignments_updated_at

BEFORE UPDATE ON competition.user_challenge_assignments

FOR EACH ROW

EXECUTE FUNCTION platform.set_updated_at();
