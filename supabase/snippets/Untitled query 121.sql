ALTER ROLE authenticator SET pgrst.db_schemas = 'public, graphql_public, app, competition, prayer, platform';
NOTIFY pgrst;