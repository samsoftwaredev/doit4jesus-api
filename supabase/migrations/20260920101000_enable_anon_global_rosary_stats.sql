-- Allow PostgREST's anonymous role to resolve the public Rosary statistics RPC.
-- search_churches previously inherited execute from PUBLIC; revoke that implicit
-- privilege before granting anonymous usage on the api schema.

revoke execute on function api.search_churches(text, text, text, integer, integer)
from public, anon;

grant usage on schema api to anon;
