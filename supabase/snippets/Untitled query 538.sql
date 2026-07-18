INSERT INTO competition.badge_definitions (
    code,
    name,
    description,
    category,
    rarity,
    icon_url,
    locked_icon_url,
    requirement_type,
    requirement_value,
    rules,
    points_reward,
    is_repeatable,
    is_shareable,
    is_active
)
VALUES
    (
        'SCRIPTURE_SEEKER_7',
        'Scripture Seeker',
        'Read Scripture for 7 different days.',
        'scripture',
        'common',
        '/icons/badges/scripture-seeker.png',
        '/icons/badges/locked/scripture-seeker.png',
        'activity_count',
        7,
        '{
            "activityCode": "SCRIPTURE_READ",
            "requiresDistinctDays": true,
            "timeWindow": "lifetime",
            "virtues": ["faith", "wisdom"]
        }'::jsonb,
        100,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'GOSPEL_WARRIOR_30',
        'Gospel Warrior',
        'Read Scripture for 30 different days.',
        'scripture',
        'rare',
        '/icons/badges/gospel-warrior.png',
        '/icons/badges/locked/gospel-warrior.png',
        'activity_count',
        30,
        '{
            "activityCode": "SCRIPTURE_READ",
            "requiresDistinctDays": true,
            "timeWindow": "lifetime",
            "virtues": ["faith", "wisdom", "discipline"]
        }'::jsonb,
        400,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'ROSARY_APPRENTICE_5',
        'Rosary Apprentice',
        'Complete 5 Rosary prayer activities.',
        'prayer',
        'common',
        '/icons/badges/rosary-apprentice.png',
        '/icons/badges/locked/rosary-apprentice.png',
        'activity_count',
        5,
        '{
            "activityCode": "ROSARY_COMPLETED",
            "timeWindow": "lifetime",
            "minimumDecades": 1,
            "virtues": ["faith", "perseverance"]
        }'::jsonb,
        100,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'ROSARY_KNIGHT_25',
        'Rosary Knight',
        'Complete 25 Rosary prayer activities.',
        'prayer',
        'epic',
        '/icons/badges/rosary-knight.png',
        '/icons/badges/locked/rosary-knight.png',
        'activity_count',
        25,
        '{
            "activityCode": "ROSARY_COMPLETED",
            "timeWindow": "lifetime",
            "virtues": ["faith", "purity", "discipline", "perseverance"]
        }'::jsonb,
        500,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'PRAYER_FLAME_10',
        'Prayer Flame',
        'Complete 10 focused prayer sessions.',
        'prayer',
        'uncommon',
        '/icons/badges/prayer-flame.png',
        '/icons/badges/locked/prayer-flame.png',
        'activity_count',
        10,
        '{
            "activityCode": "PRAYER_COMPLETED",
            "timeWindow": "lifetime",
            "minimumMinutes": 5,
            "virtues": ["faith", "perseverance"]
        }'::jsonb,
        150,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'EXAMEN_KEEPER_7',
        'Examen Keeper',
        'Complete the evening examen for 7 different days.',
        'prayer',
        'uncommon',
        '/icons/badges/examen-keeper.png',
        '/icons/badges/locked/examen-keeper.png',
        'activity_count',
        7,
        '{
            "activityCode": "EXAMEN_COMPLETED",
            "requiresDistinctDays": true,
            "timeWindow": "lifetime",
            "recommendedTimeOfDay": "evening",
            "virtues": ["humility", "wisdom", "perseverance"]
        }'::jsonb,
        150,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'MERCY_HANDS_10',
        'Mercy Hands',
        'Complete 10 acts of mercy or service.',
        'service',
        'uncommon',
        '/icons/badges/mercy-hands.png',
        '/icons/badges/locked/mercy-hands.png',
        'activity_count',
        10,
        '{
            "activityCode": "ACT_OF_MERCY_COMPLETED",
            "timeWindow": "lifetime",
            "encourageVariety": true,
            "virtues": ["charity", "humility", "service"]
        }'::jsonb,
        200,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'DISCIPLINE_SHIELD_14',
        'Discipline Shield',
        'Complete 14 discipline-building activities.',
        'discipline',
        'rare',
        '/icons/badges/discipline-shield.png',
        '/icons/badges/locked/discipline-shield.png',
        'activity_group_count',
        14,
        '{
            "activityCodes": [
                "PHONE_FAST_COMPLETED",
                "ROOM_CLEANED",
                "EXERCISE_COMPLETED",
                "DEMON_DEFENSE_COMPLETED"
            ],
            "timeWindow": "lifetime",
            "virtues": ["discipline", "temperance", "courage"]
        }'::jsonb,
        300,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'BROTHERHOOD_SPARK_10',
        'Brotherhood Spark',
        'Encourage or contact others 10 times.',
        'community',
        'common',
        '/icons/badges/brotherhood-spark.png',
        '/icons/badges/locked/brotherhood-spark.png',
        'activity_group_count',
        10,
        '{
            "activityCodes": [
                "ENCOURAGEMENT_SENT",
                "FRIEND_CONTACTED"
            ],
            "timeWindow": "lifetime",
            "freeTextAllowed": false,
            "virtues": ["charity", "community"]
        }'::jsonb,
        100,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'ARENA_CLEANSER_7',
        'Arena Cleanser',
        'Defeat 7 demons in the arena.',
        'achievement',
        'legendary',
        '/icons/badges/arena-cleanser.png',
        '/icons/badges/locked/arena-cleanser.png',
        'activity_count',
        7,
        '{
            "activityCode": "DEMON_DEFEATED",
            "timeWindow": "lifetime",
            "requiresArena": true,
            "unlocksGuardianTheme": true,
            "virtues": ["courage", "discipline", "perseverance", "faith"]
        }'::jsonb,
        1000,
        FALSE,
        TRUE,
        TRUE
    )
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    rarity = EXCLUDED.rarity,
    icon_url = EXCLUDED.icon_url,
    locked_icon_url = EXCLUDED.locked_icon_url,
    requirement_type = EXCLUDED.requirement_type,
    requirement_value = EXCLUDED.requirement_value,
    rules = EXCLUDED.rules,
    points_reward = EXCLUDED.points_reward,
    is_repeatable = EXCLUDED.is_repeatable,
    is_shareable = EXCLUDED.is_shareable,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();