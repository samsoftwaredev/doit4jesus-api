CREATE TABLE competition.challenge_progress_events (

  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

  assignment_id UUID NOT NULL

    REFERENCES competition.user_challenge_assignments(id)

    ON DELETE CASCADE,

  

  activity_id UUID

    REFERENCES competition.spiritual_activities(id),

  

  increment_amount INTEGER NOT NULL

    CHECK (increment_amount > 0),

  

  previous_progress INTEGER NOT NULL

    CHECK (previous_progress >= 0),

  

  resulting_progress INTEGER NOT NULL

    CHECK (resulting_progress >= 0),

  

  idempotency_key VARCHAR(150) NOT NULL UNIQUE,

  

  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

  CHECK (resulting_progress >= previous_progress)

);

  

CREATE INDEX idx_challenge_progress_assignment

  ON competition.challenge_progress_events(

    assignment_id,

    occurred_at DESC

  );