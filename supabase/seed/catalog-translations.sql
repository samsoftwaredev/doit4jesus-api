-- The forward migration owns the curated translation payload so deployed and
-- freshly seeded databases use exactly the same catalog copy.
select platform.apply_spanish_catalog_translations();
