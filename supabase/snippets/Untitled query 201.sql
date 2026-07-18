INSERT INTO competition.activity_definitions (
    code,
    name,
    description,
    category,
    requires_duration,
    requires_verification,
    is_repeatable,
    is_active
)
VALUES
    (
        'SCRIPTURE_READ',
        'Scripture Read',
        'User reads the daily Scripture, Gospel, or assigned Bible passage.',
        'scripture',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'PRAYER_COMPLETED',
        'Prayer Completed',
        'User completes a focused prayer session, meditation, or time of prayer.',
        'prayer',
        TRUE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'ROSARY_COMPLETED',
        'Rosary Completed',
        'User completes a Rosary prayer activity. Specific challenge rules can define one decade, three Rosaries, or a full Rosary.',
        'prayer',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'EXAMEN_COMPLETED',
        'Examen Completed',
        'User completes an evening examen or personal examination of conscience.',
        'prayer',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'PHONE_FAST_COMPLETED',
        'Phone Fast Completed',
        'User completes a voluntary phone or social media fast to fight distraction and build discipline.',
        'sacrifice',
        TRUE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'ROOM_CLEANED',
        'Room Cleaned',
        'User cleans their room, desk, or workspace as an act of order and discipline.',
        'discipline',
        TRUE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'EXERCISE_COMPLETED',
        'Exercise Completed',
        'User completes a physical exercise activity to build discipline and fight sloth or boredom.',
        'discipline',
        TRUE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'FRIEND_CONTACTED',
        'Friend Contacted',
        'User contacts a trusted friend, family member, mentor, or accountability partner instead of isolating.',
        'community',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'ACT_OF_MERCY_COMPLETED',
        'Act of Mercy Completed',
        'User completes a concrete act of charity, mercy, or service for another person.',
        'service',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'ENCOURAGEMENT_SENT',
        'Encouragement Sent',
        'User sends a preset encouragement icon or message to another user, usually after that friend earns a badge or achievement.',
        'community',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'DEMON_DEFENSE_COMPLETED',
        'Demon Defense Completed',
        'User completes a real-world defense action against an active demon battle.',
        'discipline',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'DEMON_DEFEATED',
        'Demon Defeated',
        'User defeats an active demon by completing enough real-world defense actions.',
        'discipline',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'CONFESSION_PREP_COMPLETED',
        'Confession Preparation Completed',
        'User completes an examination of conscience and prepares honestly for Confession. This does not replace the sacrament.',
        'prayer',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'MASS_ATTENDED',
        'Mass Attended',
        'User attends Mass and records the activity for spiritual habit tracking.',
        'prayer',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    ),
    (
        'CHALLENGE_COMPLETED',
        'Challenge Completed',
        'User completes a general challenge, often used for special recovery or reset missions.',
        'other',
        FALSE,
        FALSE,
        TRUE,
        TRUE
    )
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    requires_duration = EXCLUDED.requires_duration,
    requires_verification = EXCLUDED.requires_verification,
    is_repeatable = EXCLUDED.is_repeatable,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();