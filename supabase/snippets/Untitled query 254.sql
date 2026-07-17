CREATE INDEX idx_spiritual_activities_user_occurred

  ON competition.spiritual_activities (

    user_id,

    occurred_at DESC

  );

  

CREATE INDEX idx_spiritual_activities_type_date

  ON competition.spiritual_activities (

    activity_code,

    occurred_at DESC

  );

  

CREATE INDEX idx_spiritual_activities_country_date

  ON competition.spiritual_activities (

    country_code,

    occurred_at DESC

  );

  

CREATE INDEX idx_spiritual_activities_metadata

  ON competition.spiritual_activities

  USING GIN(metadata);