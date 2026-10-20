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
declare
  leaderboard_function text := pg_get_functiondef(
    'competition.refresh_leaderboard_period(uuid)'::regprocedure
  );
begin
  if position(
    'legacy_balance' in leaderboard_function
  ) = 0 then
    raise exception 'Legacy XP balances are not excluded from period leaderboards';
  end if;

  if position(
    'order by totals.rosaries_count desc' in leaderboard_function
  ) = 0 then
    raise exception 'Global leaderboards are not ranked by Rosary quantity';
  end if;

  if position(
    'activity.occurred_at <= v_period.ends_at' in leaderboard_function
  ) = 0 or position(
    'v_period.period_type = ''lifetime''' in leaderboard_function
  ) = 0 then
    raise exception 'Lifetime leaderboards do not include all qualifying Rosaries through the refresh cutoff';
  end if;

  if (
    select count(*)
    from competition.leaderboard_periods period_record
    where period_record.period_type = 'lifetime'
      and period_record.code = 'lifetime'
      and period_record.status = 'active'
  ) <> 1 then
    raise exception 'Exactly one active lifetime leaderboard period is required';
  end if;
end
$$;
