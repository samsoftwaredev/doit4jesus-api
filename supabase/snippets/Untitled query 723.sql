CREATE TRIGGER trg_users_updated_at

BEFORE UPDATE ON app.users

FOR EACH ROW

EXECUTE FUNCTION platform.set_updated_at();