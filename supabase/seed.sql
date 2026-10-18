-- Production-safe default seed hook.
--
-- Authoritative country, gameplay, and examination-of-conscience catalog data
-- is installed by forward migrations. This file intentionally contains no
-- authentication users, credentials, roles, churches, or operational fixtures.

select platform.apply_spanish_catalog_translations();
