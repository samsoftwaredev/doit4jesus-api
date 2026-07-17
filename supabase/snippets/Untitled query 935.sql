CREATE OR REPLACE FUNCTION platform.set_updated_at()

RETURNS TRIGGER

LANGUAGE plpgsql

AS $$

BEGIN

  NEW.updated_at = NOW();

  RETURN NEW;

END;

$$;