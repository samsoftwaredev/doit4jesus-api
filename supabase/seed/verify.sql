-- Verify only catalog and schema invariants in the default, production-safe
-- seed path. Operational fixture completeness is checked separately.

do $$
declare
  missing_translations integer;
begin
  select sum(missing_count)::integer
  into missing_translations
  from (
    select count(*) as missing_count from competition.level_definitions where is_active and not (translations ? 'es')
    union all select count(*) from competition.badge_definitions where is_active and not (translations ? 'es')
    union all select count(*) from competition.badge_requirement_definitions where not (translations ? 'es')
    union all select count(*) from competition.virtue_definitions where is_active and not (translations ? 'es')
    union all select count(*) from competition.saint_definitions where is_active and not (translations ? 'es')
    union all select count(*) from competition.demon_definitions where is_active and not (translations ? 'es')
    union all select count(*) from competition.demon_attacks where not (translations ? 'es')
    union all select count(*) from competition.demon_defenses where not (translations ? 'es')
    union all select count(*) from competition.challenge_definitions where is_active and not (translations ? 'es')
    union all select count(*) from app.examination_of_conscience_questions where is_active and not (translations ? 'es')
  ) as catalog_checks;

  if missing_translations <> 0 then
    raise exception 'Seed catalog is missing % Spanish translations', missing_translations;
  end if;
end
$$;
do $$
begin
  if to_regclass('prayer.prayer_events') is not null then
    raise exception 'The retired prayer.prayer_events ledger still exists';
  end if;

  if not exists (
    select 1
    from competition.badge_definitions badge
    join competition.badge_requirement_definitions requirement
      on requirement.badge_id = badge.id
    join competition.badge_requirement_activity_rules activity_rule
      on activity_rule.badge_requirement_id = requirement.id
    where badge.code = 'FIRST_ROSARY'
      and requirement.required_value = 1
      and activity_rule.activity_code = 'ROSARY'
      and activity_rule.progress_mode = 'activity_quantity'
      and activity_rule.metadata_filter = '{}'::jsonb
  ) then
    raise exception 'FIRST_ROSARY must have a canonical Rosary activity rule';
  end if;

  if not exists (
    select 1
    from competition.badge_definitions badge
    join competition.badge_requirement_definitions requirement
      on requirement.badge_id = badge.id
    join competition.badge_requirement_activity_rules activity_rule
      on activity_rule.badge_requirement_id = requirement.id
    where badge.code = 'SCRIPTURE_SEEKER'
      and requirement.required_value = 5
      and activity_rule.activity_code = 'SCRIPTURE'
      and activity_rule.progress_mode = 'activity_quantity'
      and activity_rule.metadata_filter = '{}'::jsonb
  ) then
    raise exception 'SCRIPTURE_SEEKER must have a canonical Scripture activity rule';
  end if;
end
$$;

do $$
begin
  if position(
    'legacy_balance' in pg_get_functiondef(
      'competition.refresh_leaderboard_period(uuid)'::regprocedure
    )
  ) = 0 then
    raise exception 'Legacy XP balances are not excluded from period leaderboards';
  end if;
end
$$;
