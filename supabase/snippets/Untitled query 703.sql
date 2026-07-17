CREATE TABLE app.cities (

   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  

   country_code CHAR(2) NOT NULL

      REFERENCES app.countries(code),

  

   name VARCHAR(150) NOT NULL,

   region_name VARCHAR(150),

  

   latitude NUMERIC(9, 6) NOT NULL,

   longitude NUMERIC(9, 6) NOT NULL,

  

   timezone VARCHAR(100),

  

   is_active BOOLEAN NOT NULL DEFAULT TRUE,

  

   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  

   UNIQUE (

      country_code,

      name,

      region_name

   )

);

  

CREATE INDEX idx_cities_country

   ON app.cities(country_code);

  

ALTER TABLE app.user_profiles

ADD CONSTRAINT fk_user_profiles_city

FOREIGN KEY (city_id)

REFERENCES app.cities(id);