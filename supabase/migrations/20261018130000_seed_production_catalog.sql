-- Authoritative production catalog data extracted from the former mixed
-- development seed. Unknown catalog rows are preserved; known rows are updated.

do $$
begin
  if exists (
    select 1
    from auth.users auth_user
    where auth_user.id = any (array[
      '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002'::uuid,
      '33333333-3333-4333-8333-333333333333'::uuid,
      '11111111-1111-4111-8111-111111111111'::uuid,
      '22222222-2222-4222-8222-222222222222'::uuid
    ])
      or lower(auth_user.email) = any (array[
        'test@test.com',
        'test@admin.com',
        'maria@example.com',
        'john@example.com'
      ])
  ) then
    raise exception 'PRODUCTION_DEV_ACCOUNT_PRESENT'
      using errcode = 'P0001',
        detail = 'A known local fixture account exists. Audit and remove it under a separately approved backup-first plan.';
  end if;
end
$$;

insert into app.countries (code, name, latitude, longitude, is_active)
values
  ('US', 'United States', 39.828300, -98.579500, true),
  ('MX', 'Mexico', 23.634500, -102.552800, true),
  ('VA', 'Vatican City', 41.902900, 12.453400, true)
on conflict (code) do update
set
  name = excluded.name,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  is_active = excluded.is_active;

-- Competition definitions
-- ---------------------------------------------------------------------------

insert into competition.activity_definitions (
  code,
  name,
  description,
  category,
  requires_duration,
  requires_verification,
  is_repeatable,
  is_active
)
values
  ('ROSARY', 'Pray the Rosary', 'Complete one full rosary.', 'prayer', true, false, true, true),
  ('SCRIPTURE', 'Read Scripture', 'Spend time reading and reflecting on Scripture.', 'scripture', true, false, true, true),
  ('PRAYER', 'Personal Prayer', 'Complete a personal prayer session.', 'prayer', true, false, true, true),
  ('ADORATION', 'Eucharistic Adoration', 'Spend time in Eucharistic adoration.', 'prayer', true, false, true, true),
  ('SERVICE', 'Act of Service', 'Serve a neighbor or the community.', 'service', false, true, true, true),
  ('FASTING', 'Fasting', 'Offer a voluntary fast or sacrifice.', 'sacrifice', true, false, true, true),
  ('HONESTY_REFLECTION', 'Honesty Reflection', 'Reflect honestly on one choice and its impact.', 'discipline', false, false, true, true),
  ('TRUST_ACT', 'Act of Trust', 'Record a concrete act of trust during difficulty.', 'discipline', false, false, true, true),
  ('RULE_OF_LIFE', 'Rule of Life', 'Complete the daily commitments in your rule of life.', 'discipline', false, false, true, true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  requires_duration = excluded.requires_duration,
  requires_verification = excluded.requires_verification,
  is_repeatable = excluded.is_repeatable,
  is_active = excluded.is_active;

insert into competition.level_definitions (
  level_number,
  code,
  name,
  description,
  minimum_total_xp,
  icon_url,
  image_url,
  reward_type,
  is_active
)
values
  (1, 'awakened', 'Awakened', 'Begins recognizing the battle.', 0, '/levels/awakened-icon.png', '/levels/awakened.png', 'title', true),
  (2, 'seeker', 'Seeker', 'Starts building daily habits.', 250, '/levels/seeker-icon.png', '/levels/seeker.png', 'title', true),
  (3, 'disciple', 'Disciple', 'Follows a consistent rule of life.', 750, '/levels/disciple-icon.png', '/levels/disciple.png', 'title', true),
  (4, 'fighter', 'Fighter', 'Resists recurring temptations.', 1500, '/levels/fighter-icon.png', '/levels/fighter.png', 'title', true),
  (5, 'guardian', 'Guardian', 'Protects his environment and relationships.', 3000, '/levels/guardian-icon.png', '/levels/guardian.png', 'title', true),
  (6, 'servant', 'Servant', 'Regularly serves others.', 5000, '/levels/servant-icon.png', '/levels/servant.png', 'title', true),
  (7, 'brother', 'Brother', 'Supports other men.', 7500, '/levels/brother-icon.png', '/levels/brother.png', 'title', true),
  (8, 'leader', 'Leader', 'Leads by example.', 11000, '/levels/leader-icon.png', '/levels/leader.png', 'title', true),
  (9, 'witness', 'Witness', 'Lives the faith publicly and consistently.', 16000, '/levels/witness-icon.png', '/levels/witness.png', 'title', true),
  (10, 'persevering_disciple', 'Persevering Disciple', 'Continues faithfully over time.', 22000, '/levels/persevering-disciple-icon.png', '/levels/persevering-disciple.png', 'title', true)
on conflict (level_number) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  minimum_total_xp = excluded.minimum_total_xp,
  icon_url = excluded.icon_url,
  image_url = excluded.image_url,
  reward_type = excluded.reward_type,
  is_active = excluded.is_active;

insert into competition.badge_definitions (
  id,
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
values
  ('80000000-0000-4000-8000-000000000001', 'FIRST_ROSARY', 'First Rosary', 'Pray your first complete rosary.', 'prayer', 'common', '/badges/first-rosary.png', '/badges/locked.png', 'activity_count', 1, '{"activityCode":"ROSARY"}'::jsonb, 25, false, true, true),
  ('80000000-0000-4000-8000-000000000002', 'SCRIPTURE_SEEKER', 'Scripture Seeker', 'Complete five Scripture reading sessions.', 'scripture', 'uncommon', '/badges/scripture-seeker.png', '/badges/locked.png', 'activity_count', 5, '{"activityCode":"SCRIPTURE"}'::jsonb, 50, false, true, true),
  ('80000000-0000-4000-8000-000000000003', 'PRAYER_STREAK', 'Prayer Streak', 'Pray on seven consecutive days.', 'discipline', 'rare', '/badges/prayer-streak.png', '/badges/locked.png', 'daily_streak', 7, '{"days":7}'::jsonb, 100, false, true, true),
  ('80000000-0000-4000-8000-000000000004', 'COMMUNITY_HELPER', 'Community Helper', 'Complete three acts of service.', 'service', 'uncommon', '/badges/community-helper.png', '/badges/locked.png', 'activity_count', 3, '{"activityCode":"SERVICE"}'::jsonb, 50, false, true, true),
  ('80000000-0000-4000-8000-000000000005', 'BELT_OF_TRUTH', 'Belt of Truth', 'Wear the Belt of Truth by practicing honesty and integrity each day.', 'discipline', 'uncommon', '/badges/belt-of-truth.png', '/badges/locked.png', 'daily_streak', 7, '{"virtue":"truth","requirements":[{"type":"daily_honesty_reflection","value":7}]}'::jsonb, 75, false, true, true),
  ('80000000-0000-4000-8000-000000000006', 'SHIELD_OF_FAITH', 'Shield of Faith', 'Unlock the Shield of Faith through sustained prayer, Scripture, and trust during difficulty.', 'prayer', 'rare', '/badges/shield-of-faith.png', '/badges/locked.png', 'all_requirements', 3, '{"virtue":"faith","requirements":[{"type":"prayer_days","value":7,"description":"Seven days of prayer"},{"type":"scripture_plan_completed","value":1,"description":"One completed Scripture plan"},{"type":"trust_act_during_difficulty","value":1,"description":"One act of trust during difficulty"}]}'::jsonb, 150, false, true, true),
  ('80000000-0000-4000-8000-000000000007', 'SWORD_OF_THE_SPIRIT', 'Sword of the Spirit', 'Unlock the Sword of the Spirit by storing God’s word in your heart.', 'scripture', 'rare', '/badges/sword-of-the-spirit.png', '/badges/locked.png', 'activity_count', 10, '{"virtue":"wisdom","requirements":[{"type":"scripture_reading_sessions","value":10}]}'::jsonb, 125, false, true, true),
  ('80000000-0000-4000-8000-000000000008', 'HELMET_OF_SALVATION', 'Helmet of Salvation', 'Unlock the Helmet of Salvation by renewing hope and guarding your mind.', 'discipline', 'rare', '/badges/helmet-of-salvation.png', '/badges/locked.png', 'daily_streak', 14, '{"virtue":"hope","requirements":[{"type":"daily_prayer_streak","value":14}]}'::jsonb, 125, false, true, true),
  ('80000000-0000-4000-8000-000000000009', 'BOOTS_OF_READINESS', 'Boots of Readiness', 'Unlock the Boots of Readiness by being ready to serve and bring peace.', 'service', 'uncommon', '/badges/boots-of-readiness.png', '/badges/locked.png', 'activity_count', 5, '{"virtue":"readiness","requirements":[{"type":"service_acts","value":5}]}'::jsonb, 100, false, true, true),
  ('80000000-0000-4000-8000-000000000010', 'BREASTPLATE_OF_RIGHTEOUSNESS', 'Breastplate of Righteousness', 'Unlock the Breastplate of Righteousness through consistent righteous choices.', 'discipline', 'epic', '/badges/breastplate-of-righteousness.png', '/badges/locked.png', 'daily_streak', 21, '{"virtue":"righteousness","requirements":[{"type":"daily_rule_of_life_streak","value":21}]}'::jsonb, 200, false, true, true),
  ('80000000-0000-4000-8000-000000000011', 'CHURCH_SCHEDULE_STEWARD', 'Church Schedule Steward', 'Keep a church''s worship schedule current. Earned for every approved schedule update.', 'community', 'common', '/badges/community-helper.png', '/badges/locked.png', 'approved_church_schedule_update', 1, '{"requestType":"schedule_update"}'::jsonb, 0, true, true, true)
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  rarity = excluded.rarity,
  icon_url = excluded.icon_url,
  locked_icon_url = excluded.locked_icon_url,
  requirement_type = excluded.requirement_type,
  requirement_value = excluded.requirement_value,
  rules = excluded.rules,
  points_reward = excluded.points_reward,
  is_repeatable = excluded.is_repeatable,
  is_shareable = excluded.is_shareable,
  is_active = excluded.is_active;

-- ---------------------------------------------------------------------------
-- Fictional spiritual-battle game configuration
-- ---------------------------------------------------------------------------

insert into competition.game_balance_config (
  id,
  schema_version,
  virtue_min,
  virtue_max,
  default_virtue_value,
  demon_default_max_hp,
  attack_penalty_min,
  attack_penalty_max,
  challenge_reward_min,
  challenge_reward_max,
  rules
)
values (
  true,
  '1.0.0',
  0,
  100,
  50,
  100,
  2,
  8,
  3,
  10,
  jsonb_build_array(
    'The server calculates all virtue changes, demon damage, XP, and rewards.',
    'Virtues cannot drop below 0 or rise above 100.',
    'A missed challenge should create only a small, recoverable penalty.',
    'A completed defense increases the associated virtue and damages the demon.',
    'Defeating a demon grants a final bonus to its primary counter-virtue.',
    'Saints are thematic mentors and examples, not magical power-ups.'
  )
)
on conflict (id) do update
set
  schema_version = excluded.schema_version,
  virtue_min = excluded.virtue_min,
  virtue_max = excluded.virtue_max,
  default_virtue_value = excluded.default_virtue_value,
  demon_default_max_hp = excluded.demon_default_max_hp,
  attack_penalty_min = excluded.attack_penalty_min,
  attack_penalty_max = excluded.attack_penalty_max,
  challenge_reward_min = excluded.challenge_reward_min,
  challenge_reward_max = excluded.challenge_reward_max,
  rules = excluded.rules;

insert into competition.virtue_definitions (
  code,
  name,
  description,
  default_value,
  icon,
  is_active
)
values
  ('FAITH', 'Faith', 'Trust in God and willingness to remain close to Him.', 50, 'shield-cross', true),
  ('DISCIPLINE', 'Discipline', 'Choosing the good even when motivation is low.', 50, 'belt', true),
  ('COURAGE', 'Courage', 'Facing fear, discomfort, responsibility, and difficult truth.', 50, 'sword', true),
  ('WISDOM', 'Wisdom', 'Recognizing truth and choosing the next good action.', 50, 'open-book', true),
  ('CHARITY', 'Charity', 'Loving others through patience, mercy, service, and truth.', 50, 'sacred-heart', true),
  ('PURITY', 'Purity', 'Seeing people with dignity and guarding the heart and imagination.', 50, 'lily-shield', true),
  ('PERSEVERANCE', 'Perseverance', 'Returning and continuing after difficulty or failure.', 50, 'boots', true),
  ('HUMILITY', 'Humility', 'Living truthfully without self-exaltation or self-contempt.', 50, 'kneeling-knight', true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  default_value = excluded.default_value,
  icon = excluded.icon,
  is_active = excluded.is_active;

insert into competition.saint_definitions (id, code, name, description, is_active)
values
  ('a1000000-0000-4000-8000-000000000001', 'IGNATIUS_OF_LOYOLA', 'St. Ignatius of Loyola', 'A mentor of discernment and ordered attention.', true),
  ('a1000000-0000-4000-8000-000000000002', 'JOSEPH', 'St. Joseph', 'A mentor of steady work, responsibility, and quiet service.', true),
  ('a1000000-0000-4000-8000-000000000003', 'FRANCIS_DE_SALES', 'St. Francis de Sales', 'A mentor of gentleness and patient speech.', true),
  ('a1000000-0000-4000-8000-000000000004', 'THERESE_OF_LISIEUX', 'St. Thérèse of Lisieux', 'A mentor of hidden love and the little way.', true),
  ('a1000000-0000-4000-8000-000000000005', 'BENEDICT', 'St. Benedict of Nursia', 'A mentor of prayerful work, stability, and holy order.', true),
  ('a1000000-0000-4000-8000-000000000006', 'FRANCIS_OF_ASSISI', 'St. Francis of Assisi', 'A mentor of gratitude, simplicity, and joy in the good of others.', true),
  ('a1000000-0000-4000-8000-000000000007', 'JOAN_OF_ARC', 'St. Joan of Arc', 'A mentor of courageous obedience despite fear.', true),
  ('a1000000-0000-4000-8000-000000000008', 'PETER', 'St. Peter', 'A mentor of repentance and returning after failure.', true),
  ('a1000000-0000-4000-8000-000000000009', 'PHILIP_NERI', 'St. Philip Neri', 'A mentor of joyful charity and practical wisdom.', true),
  ('a1000000-0000-4000-8000-000000000010', 'LAWRENCE', 'St. Lawrence', 'A mentor of generosity and love of people over possessions.', true),
  ('a1000000-0000-4000-8000-000000000011', 'MARIA_GORETTI', 'St. Maria Goretti', 'A mentor of purity, dignity, forgiveness, and courage.', true),
  ('a1000000-0000-4000-8000-000000000012', 'BLESSED_VIRGIN_MARY', 'Blessed Virgin Mary', 'A motherly mentor of faith, humility, and steadfast hope.', true),
  ('a1000000-0000-4000-8000-000000000013', 'OUR_LADY_QUEEN_OF_HEAVEN', 'Our Lady, Queen of Heaven', 'A mentor of prayer, trust, and hope in Christ.', true),
  ('a1000000-0000-4000-8000-000000000014', 'ANTHONY_OF_PADUA', 'St. Anthony of Padua', 'A mentor of perseverance, learning, and care for the poor.', true),
  ('a1000000-0000-4000-8000-000000000015', 'AUGUSTINE_OF_HIPPO', 'St. Augustine of Hippo', 'A mentor of conversion, truth, and hearts returning to God.', true),
  ('a1000000-0000-4000-8000-000000000016', 'CATHERINE_OF_SIENA', 'St. Catherine of Siena', 'A mentor of courage, truth, and love for the Church.', true),
  ('a1000000-0000-4000-8000-000000000017', 'CECILIA', 'St. Cecilia', 'A mentor of joyful worship, purity, and courageous witness.', true),
  ('a1000000-0000-4000-8000-000000000018', 'DOMINIC', 'St. Dominic', 'A mentor of preaching, study, and charity rooted in truth.', true),
  ('a1000000-0000-4000-8000-000000000019', 'DYMPHNA', 'St. Dymphna', 'A mentor of compassion, peace of mind, and courageous trust.', true),
  ('a1000000-0000-4000-8000-000000000020', 'FRANCIS_XAVIER', 'St. Francis Xavier', 'A mentor of mission, generosity, and bringing Christ to others.', true),
  ('a1000000-0000-4000-8000-000000000021', 'JOHN_PAUL_II', 'St. John Paul II', 'A mentor of human dignity, courage, and joyful faith.', true),
  ('a1000000-0000-4000-8000-000000000022', 'JOHN_THE_EVANGELIST', 'St. John the Evangelist', 'A mentor of faithful friendship, love, and bold witness.', true),
  ('a1000000-0000-4000-8000-000000000023', 'JUAN_DIEGO', 'St. Juan Diego', 'A mentor of humility, obedience, and sharing hope with others.', true),
  ('a1000000-0000-4000-8000-000000000024', 'MAXIMILIAN_KOLBE', 'St. Maximilian Kolbe', 'A mentor of self-giving love, courage, and hope amid suffering.', true),
  ('a1000000-0000-4000-8000-000000000025', 'MICHAEL_THE_ARCHANGEL', 'St. Michael the Archangel', 'A mentor of spiritual courage, protection, and fidelity to God.', true),
  ('a1000000-0000-4000-8000-000000000026', 'MONICA', 'St. Monica', 'A mentor of patient prayer, perseverance, and hopeful love.', true),
  ('a1000000-0000-4000-8000-000000000027', 'NICHOLAS', 'St. Nicholas', 'A mentor of secret generosity, care for children, and compassion.', true),
  ('a1000000-0000-4000-8000-000000000028', 'PADRE_PIO', 'St. Padre Pio', 'A mentor of prayer, suffering offered in love, and reconciliation.', true),
  ('a1000000-0000-4000-8000-000000000029', 'PATRICK', 'St. Patrick', 'A mentor of missionary courage, forgiveness, and faithful service.', true),
  ('a1000000-0000-4000-8000-000000000030', 'PAUL', 'St. Paul', 'A mentor of conversion, zeal, and sharing the Gospel boldly.', true),
  ('a1000000-0000-4000-8000-000000000031', 'SEBASTIAN', 'St. Sebastian', 'A mentor of steadfast courage, faithfulness, and hope under trial.', true),
  ('a1000000-0000-4000-8000-000000000032', 'TERESA_OF_AVILA', 'St. Teresa of Ávila', 'A mentor of interior prayer, friendship with God, and courage.', true),
  ('a1000000-0000-4000-8000-000000000033', 'TERESA_OF_CALCUTTA', 'St. Teresa of Calcutta', 'A mentor of merciful service, simplicity, and love for the poor.', true),
  ('a1000000-0000-4000-8000-000000000034', 'THOMAS_AQUINAS', 'St. Thomas Aquinas', 'A mentor of faith, reason, study, and love of truth.', true)
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into competition.demon_definitions (
  id,
  code,
  name,
  title,
  description,
  category,
  silly_personality,
  saint_mentor_id,
  saint_mentor_reason,
  max_hp,
  safety_note,
  is_active
)
values
  ('b1000000-0000-4000-8000-000000000001', 'SCROLLZILLA', 'Scrollzilla', 'The Endless Scroller', 'A tiny red nuisance with enormous thumbs who feeds on notifications, short videos, and bedtime procrastination.', 'DISTRACTION', 'Carries three phones but never remembers where any of them are.', 'a1000000-0000-4000-8000-000000000001', 'Discernment and ordered attention expose Scrollzilla tricks.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000002', 'SNOOZLEUMP', 'Snoozleump', 'The Blanket Commander', 'A sleepy blob that declares every responsibility can safely wait until tomorrow.', 'SLOTH', 'Wears a pillow as a crown and snores during his own speeches.', 'a1000000-0000-4000-8000-000000000002', 'Steady work, responsibility, and quiet service weaken Snoozleump.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000003', 'GRUMBLEPUFF', 'Grumblepuff', 'The Complaint Cloud', 'A smoky little grouch who turns minor inconvenience into a five-act tragedy.', 'ANGER', 'Gets angry when soup is too hot and angrier when it gets cold.', 'a1000000-0000-4000-8000-000000000003', 'Gentleness and patient speech directly counter reactive anger.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000004', 'BRAGGLESNOUT', 'Bragglesnout', 'The Tiny Trumpeter', 'A purple horned show-off who announces every good deed with imaginary trumpets.', 'PRIDE', 'Awards himself trophies for attending meetings he scheduled.', 'a1000000-0000-4000-8000-000000000004', 'Her little way of hidden love defeats the need to be impressive.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000005', 'SNACKASAURUS', 'Snackasaurus', 'The Bottomless Muncher', 'A round demon who insists every emotion requires a snack and every snack requires another snack.', 'GLUTTONY', 'Keeps emergency cupcakes in an emergency cupcake.', 'a1000000-0000-4000-8000-000000000005', 'Moderation, order, and rhythm make excess lose its power.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000006', 'PEEKABOOZE', 'Peekabooze', 'The Comparison Gremlin', 'A green gremlin who peeks at everyone else life and edits out all their struggles.', 'ENVY', 'Owns binoculars that only point toward other peoples blessings.', 'a1000000-0000-4000-8000-000000000006', 'Gratitude, simplicity, and joy in others good expose envy.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000007', 'WOBBLEKNEES', 'Wobbleknees', 'The Cowardly Catastrophizer', 'A nervous demon who predicts twelve disasters before breakfast and hides behind a very small shield.', 'FEAR', 'Screams whenever his own cape touches him.', 'a1000000-0000-4000-8000-000000000007', 'Courageous obedience despite fear defeats his exaggerations.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000008', 'WHISPERWHOMP', 'Whisperwhomp', 'The Discouragement Mumbler', 'A shadowy fuzzball who whispers that past failure proves future effort is pointless.', 'DISCOURAGEMENT', 'Practices dramatic sighing in front of a mirror.', 'a1000000-0000-4000-8000-000000000008', 'His repentance and return after failure show that falling is not the end.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000009', 'GOSSIPGOB', 'Gossipgob', 'The Rumor Collector', 'A long-eared goblin who collects half-stories and adds three dramatic details for free.', 'GOSSIP', 'Begins every sentence with I probably should not say this, but.', 'a1000000-0000-4000-8000-000000000009', 'Joy, charity, and practical wisdom expose careless speech.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000010', 'SHINYGRAB', 'Shinygrab', 'The Checkout Goblin', 'A gold-eyed goblin who thinks every limited-time offer is a spiritual emergency.', 'GREED', 'Buys storage boxes to organize the storage boxes he already bought.', 'a1000000-0000-4000-8000-000000000010', 'Generosity and love of people over possessions defeat Shinygrab.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000011', 'FOGGLES', 'Foggles', 'The Confusion Puff', 'A blue floating eyeball surrounded by fog who makes every simple decision feel like a doctoral thesis.', 'CONFUSION', 'Needs a flowchart to decide whether to make a flowchart.', 'a1000000-0000-4000-8000-000000000001', 'Discernment, clarity, and ordered choices disperse the fog.', 100, null, true),
  ('b1000000-0000-4000-8000-000000000012', 'SNEAKYPEEKY', 'Sneakypeeky', 'The Screen-Corner Creeper', 'A pink winged imp who hides harmful content behind boredom, secrecy, and just one look.', 'IMPURITY', 'Wears sunglasses indoors because he thinks it makes him invisible.', 'a1000000-0000-4000-8000-000000000011', 'Purity, dignity, forgiveness, and courage stand against objectification and secrecy.', 100, 'For repeated compulsive behavior, encourage confidential support from a trusted adult, priest, counselor, or qualified professional; software is not treatment.', true)
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  title = excluded.title,
  description = excluded.description,
  category = excluded.category,
  silly_personality = excluded.silly_personality,
  saint_mentor_id = excluded.saint_mentor_id,
  saint_mentor_reason = excluded.saint_mentor_reason,
  max_hp = excluded.max_hp,
  safety_note = excluded.safety_note,
  is_active = excluded.is_active;

insert into competition.demon_virtue_affinities (demon_id, virtue_code, affinity_type)
values
  ('b1000000-0000-4000-8000-000000000001', 'DISCIPLINE', 'primary'), ('b1000000-0000-4000-8000-000000000001', 'WISDOM', 'secondary'), ('b1000000-0000-4000-8000-000000000001', 'PERSEVERANCE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000002', 'DISCIPLINE', 'primary'), ('b1000000-0000-4000-8000-000000000002', 'PERSEVERANCE', 'secondary'), ('b1000000-0000-4000-8000-000000000002', 'CHARITY', 'secondary'),
  ('b1000000-0000-4000-8000-000000000003', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000003', 'COURAGE', 'secondary'), ('b1000000-0000-4000-8000-000000000003', 'WISDOM', 'secondary'),
  ('b1000000-0000-4000-8000-000000000004', 'HUMILITY', 'primary'), ('b1000000-0000-4000-8000-000000000004', 'CHARITY', 'secondary'), ('b1000000-0000-4000-8000-000000000004', 'WISDOM', 'secondary'),
  ('b1000000-0000-4000-8000-000000000005', 'DISCIPLINE', 'primary'), ('b1000000-0000-4000-8000-000000000005', 'WISDOM', 'secondary'), ('b1000000-0000-4000-8000-000000000005', 'PERSEVERANCE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000006', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000006', 'HUMILITY', 'secondary'), ('b1000000-0000-4000-8000-000000000006', 'FAITH', 'secondary'),
  ('b1000000-0000-4000-8000-000000000007', 'COURAGE', 'primary'), ('b1000000-0000-4000-8000-000000000007', 'FAITH', 'secondary'), ('b1000000-0000-4000-8000-000000000007', 'PERSEVERANCE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000008', 'PERSEVERANCE', 'primary'), ('b1000000-0000-4000-8000-000000000008', 'FAITH', 'secondary'), ('b1000000-0000-4000-8000-000000000008', 'COURAGE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000009', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000009', 'WISDOM', 'secondary'), ('b1000000-0000-4000-8000-000000000009', 'HUMILITY', 'secondary'),
  ('b1000000-0000-4000-8000-000000000010', 'CHARITY', 'primary'), ('b1000000-0000-4000-8000-000000000010', 'DISCIPLINE', 'secondary'), ('b1000000-0000-4000-8000-000000000010', 'WISDOM', 'secondary'),
  ('b1000000-0000-4000-8000-000000000011', 'WISDOM', 'primary'), ('b1000000-0000-4000-8000-000000000011', 'FAITH', 'secondary'), ('b1000000-0000-4000-8000-000000000011', 'COURAGE', 'secondary'),
  ('b1000000-0000-4000-8000-000000000012', 'PURITY', 'primary'), ('b1000000-0000-4000-8000-000000000012', 'COURAGE', 'secondary'), ('b1000000-0000-4000-8000-000000000012', 'DISCIPLINE', 'secondary')
on conflict (demon_id, virtue_code) do update
set affinity_type = excluded.affinity_type;

insert into competition.demon_attacks (id, demon_id, code, name, description, target_virtue_code, virtue_decrease)
values
  ('c1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'LATE_NIGHT_SCROLLING', 'One More Video', 'Keeps the user scrolling after bedtime.', 'DISCIPLINE', 6),
  ('c1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'NOTIFICATION_STORM', 'Notification Confetti', 'Interrupts prayer, work, and family time.', 'WISDOM', 4),
  ('c1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'AVOID_THE_TASK', 'Productive-Looking Procrastination', 'Makes distraction feel useful while the real task remains untouched.', 'PERSEVERANCE', 5),
  ('c1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000002', 'SNOOZE_AGAIN', 'The Sacred Snooze Button', 'Encourages repeated delays after waking.', 'DISCIPLINE', 5),
  ('c1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000002', 'TOMORROW_TRAP', 'Tomorrow Is Definitely Better', 'Pushes necessary work into an imaginary perfect future.', 'PERSEVERANCE', 6),
  ('c1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000002', 'SERVICE_AVOIDANCE', 'Someone Else Will Do It', 'Makes service feel inconvenient and optional.', 'CHARITY', 4),
  ('c1000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000003', 'SHARP_REPLY', 'Instant Keyboard Thunder', 'Pushes the user to respond harshly before understanding.', 'CHARITY', 6),
  ('c1000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000003', 'RESENTMENT_LOOP', 'Replay the Offense', 'Repeats an offense mentally until it feels larger.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000003', 'AVOID_HARD_CONVERSATION', 'Silent Volcano', 'Avoids honest conversation while resentment builds.', 'COURAGE', 4),
  ('c1000000-0000-4000-8000-000000000010', 'b1000000-0000-4000-8000-000000000004', 'NEED_TO_BE_RIGHT', 'Actually, Technically', 'Turns every conversation into a contest.', 'HUMILITY', 6),
  ('c1000000-0000-4000-8000-000000000011', 'b1000000-0000-4000-8000-000000000004', 'SEEK_PRAISE', 'Applause Vacuum', 'Makes good actions feel worthless unless others notice.', 'CHARITY', 4),
  ('c1000000-0000-4000-8000-000000000012', 'b1000000-0000-4000-8000-000000000004', 'REFUSE_CORRECTION', 'Armor of Excuses', 'Rejects useful correction before considering it.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000013', 'b1000000-0000-4000-8000-000000000005', 'EMOTIONAL_EATING', 'Sad Snack Summoning', 'Uses food to avoid processing emotion.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000014', 'b1000000-0000-4000-8000-000000000005', 'SECOND_PORTION', 'The Plate Refill Spell', 'Pushes the user past reasonable satisfaction.', 'DISCIPLINE', 5),
  ('c1000000-0000-4000-8000-000000000015', 'b1000000-0000-4000-8000-000000000005', 'ALL_OR_NOTHING', 'Diet Drama', 'Turns one imperfect choice into giving up completely.', 'PERSEVERANCE', 4),
  ('c1000000-0000-4000-8000-000000000016', 'b1000000-0000-4000-8000-000000000006', 'SOCIAL_COMPARISON', 'Highlight-Reel Vision', 'Compares ordinary life to selected images of others.', 'HUMILITY', 5),
  ('c1000000-0000-4000-8000-000000000017', 'b1000000-0000-4000-8000-000000000006', 'RESENT_SUCCESS', 'Why Them', 'Turns another person success into resentment.', 'CHARITY', 6),
  ('c1000000-0000-4000-8000-000000000018', 'b1000000-0000-4000-8000-000000000006', 'FORGOTTEN_BLESSINGS', 'Blessing Blindfold', 'Hides what is already good in the user life.', 'FAITH', 4),
  ('c1000000-0000-4000-8000-000000000019', 'b1000000-0000-4000-8000-000000000007', 'AVOID_FIRST_STEP', 'Maybe Never Is Safer', 'Makes the first step feel more dangerous than avoidance.', 'COURAGE', 6),
  ('c1000000-0000-4000-8000-000000000020', 'b1000000-0000-4000-8000-000000000007', 'WORST_CASE_LOOP', 'Disaster Slideshow', 'Cycles through imagined worst-case outcomes.', 'FAITH', 5),
  ('c1000000-0000-4000-8000-000000000021', 'b1000000-0000-4000-8000-000000000007', 'QUIT_EARLY', 'Emergency Exit Everywhere', 'Encourages quitting before enough effort has been made.', 'PERSEVERANCE', 5),
  ('c1000000-0000-4000-8000-000000000022', 'b1000000-0000-4000-8000-000000000008', 'FAILURE_DEFINES_YOU', 'The Permanent Label', 'Treats one failure as the user complete identity.', 'PERSEVERANCE', 7),
  ('c1000000-0000-4000-8000-000000000023', 'b1000000-0000-4000-8000-000000000008', 'GOD_IS_DISTANT', 'He Is Not Listening', 'Tempts the user to abandon prayer when consolation is absent.', 'FAITH', 6),
  ('c1000000-0000-4000-8000-000000000024', 'b1000000-0000-4000-8000-000000000008', 'DO_NOT_TRY', 'Pre-Defeated', 'Convincingly loses battles before they begin.', 'COURAGE', 5),
  ('c1000000-0000-4000-8000-000000000025', 'b1000000-0000-4000-8000-000000000009', 'SHARE_RUMOR', 'Pass It Along', 'Encourages sharing information that is unverified or unnecessary.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000026', 'b1000000-0000-4000-8000-000000000009', 'MOCK_PERSON', 'Comedy at Their Expense', 'Uses another person weakness to gain attention.', 'CHARITY', 7),
  ('c1000000-0000-4000-8000-000000000027', 'b1000000-0000-4000-8000-000000000009', 'MORAL_SUPERIORITY', 'Concerned-Looking Pride', 'Disguises judgment as concern.', 'HUMILITY', 5),
  ('c1000000-0000-4000-8000-000000000028', 'b1000000-0000-4000-8000-000000000010', 'IMPULSE_PURCHASE', 'Buy Now, Discern Never', 'Turns a desire into an immediate purchase.', 'DISCIPLINE', 6),
  ('c1000000-0000-4000-8000-000000000029', 'b1000000-0000-4000-8000-000000000010', 'POSSESSION_IDENTITY', 'You Are What You Own', 'Connects personal worth to possessions and status.', 'WISDOM', 5),
  ('c1000000-0000-4000-8000-000000000030', 'b1000000-0000-4000-8000-000000000010', 'HOARD_USEFUL_ITEMS', 'Maybe Someday Mountain', 'Keeps useful goods away from people who need them.', 'CHARITY', 5),
  ('c1000000-0000-4000-8000-000000000031', 'b1000000-0000-4000-8000-000000000011', 'OVERTHINK_DECISION', 'Infinite Option Parade', 'Adds unnecessary options until no action feels possible.', 'WISDOM', 7),
  ('c1000000-0000-4000-8000-000000000032', 'b1000000-0000-4000-8000-000000000011', 'SEEK_ENDLESS_SIGNS', 'One More Sign', 'Avoids reasonable decisions by demanding absolute certainty.', 'FAITH', 5),
  ('c1000000-0000-4000-8000-000000000033', 'b1000000-0000-4000-8000-000000000011', 'FEAR_COMMITMENT', 'Decision Doorway Freeze', 'Makes commitment feel more dangerous than indecision.', 'COURAGE', 5),
  ('c1000000-0000-4000-8000-000000000034', 'b1000000-0000-4000-8000-000000000012', 'TRIGGERING_CONTENT', 'Just One Look', 'Presents harmful or objectifying content as harmless curiosity.', 'PURITY', 8),
  ('c1000000-0000-4000-8000-000000000035', 'b1000000-0000-4000-8000-000000000012', 'SECRECY', 'Nobody Has to Know', 'Uses isolation and shame to prevent seeking help.', 'COURAGE', 6),
  ('c1000000-0000-4000-8000-000000000036', 'b1000000-0000-4000-8000-000000000012', 'LATE_NIGHT_WEAKNESS', 'Midnight Ambush', 'Targets tiredness, privacy, and unstructured screen use.', 'DISCIPLINE', 6)
on conflict (id) do update
set
  demon_id = excluded.demon_id,
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  target_virtue_code = excluded.target_virtue_code,
  virtue_decrease = excluded.virtue_decrease;

insert into competition.demon_defenses (id, demon_id, code, name, challenge, reward_virtue_code, virtue_increase, demon_damage)
values
  ('d1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'PHONE_SIX_FEET_AWAY', 'The Six-Foot Exile', 'Place the phone at least six feet away for 30 minutes or before sleep.', 'DISCIPLINE', 7, 30),
  ('d1000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001', 'FOCUS_MODE', 'Silence the Bells', 'Enable Focus Mode and complete one uninterrupted 25-minute session.', 'WISDOM', 5, 25),
  ('d1000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001', 'SCRIPTURE_BEFORE_SCREEN', 'Word Before World', 'Read the daily Gospel before opening social media.', 'PERSEVERANCE', 6, 25),
  ('d1000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000002', 'MAKE_BED', 'First Victory', 'Get up and make the bed immediately.', 'DISCIPLINE', 4, 20),
  ('d1000000-0000-4000-8000-000000000005', 'b1000000-0000-4000-8000-000000000002', 'TWENTY_MINUTE_TASK', 'Twenty-Minute Charge', 'Work on the most avoided task for 20 focused minutes.', 'PERSEVERANCE', 7, 30),
  ('d1000000-0000-4000-8000-000000000006', 'b1000000-0000-4000-8000-000000000002', 'HIDDEN_SERVICE', 'Quiet Hands', 'Complete one useful act of service without seeking recognition.', 'CHARITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000007', 'b1000000-0000-4000-8000-000000000003', 'TEN_MINUTE_PAUSE', 'Lower the Drawbridge', 'Wait 10 minutes before responding and reread your message.', 'CHARITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000008', 'b1000000-0000-4000-8000-000000000003', 'PRAY_FOR_PERSON', 'Reverse the Flame', 'Pray sincerely for the person who upset you.', 'WISDOM', 5, 25),
  ('d1000000-0000-4000-8000-000000000009', 'b1000000-0000-4000-8000-000000000003', 'CALM_CONVERSATION', 'Speak the Truth Gently', 'Have one direct, respectful conversation instead of avoiding or exploding.', 'COURAGE', 7, 30),
  ('d1000000-0000-4000-8000-000000000010', 'b1000000-0000-4000-8000-000000000004', 'ADMIT_MISTAKE', 'Drop the Trophy', 'Admit one mistake clearly without adding an excuse.', 'HUMILITY', 8, 35),
  ('d1000000-0000-4000-8000-000000000011', 'b1000000-0000-4000-8000-000000000004', 'HIDDEN_KINDNESS', 'Invisible Victory', 'Perform one act of kindness and tell no one.', 'CHARITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000012', 'b1000000-0000-4000-8000-000000000004', 'LISTEN_FULLY', 'Close the Trumpet', 'Listen without interrupting or preparing your reply.', 'WISDOM', 5, 25),
  ('d1000000-0000-4000-8000-000000000013', 'b1000000-0000-4000-8000-000000000005', 'WATER_AND_WAIT', 'The Ten-Minute Truce', 'Drink water and wait 10 minutes before deciding whether to eat.', 'WISDOM', 5, 20),
  ('d1000000-0000-4000-8000-000000000014', 'b1000000-0000-4000-8000-000000000005', 'MINDFUL_PORTION', 'One Plate Pact', 'Choose a reasonable portion and eat without a screen.', 'DISCIPLINE', 7, 30),
  ('d1000000-0000-4000-8000-000000000015', 'b1000000-0000-4000-8000-000000000005', 'RETURN_NEXT_MEAL', 'No Drama Reset', 'After an imperfect choice, return to moderation at the next meal.', 'PERSEVERANCE', 6, 25),
  ('d1000000-0000-4000-8000-000000000016', 'b1000000-0000-4000-8000-000000000006', 'SOCIAL_FAST', 'Close the Binoculars', 'Take a 24-hour break from the app that triggers comparison.', 'HUMILITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000017', 'b1000000-0000-4000-8000-000000000006', 'CONGRATULATE_PERSON', 'Celebrate Their Victory', 'Congratulate someone sincerely and specifically.', 'CHARITY', 7, 30),
  ('d1000000-0000-4000-8000-000000000018', 'b1000000-0000-4000-8000-000000000006', 'FIVE_BLESSINGS', 'Open the Blessing Book', 'Write five concrete blessings from today.', 'FAITH', 5, 25),
  ('d1000000-0000-4000-8000-000000000019', 'b1000000-0000-4000-8000-000000000007', 'ONE_BRAVE_STEP', 'One Step Forward', 'Take one concrete step toward the responsibility you have avoided.', 'COURAGE', 8, 35),
  ('d1000000-0000-4000-8000-000000000020', 'b1000000-0000-4000-8000-000000000007', 'OUR_FATHER_SLOWLY', 'Trust the Father', 'Pray the Our Father slowly and identify the next controllable action.', 'FAITH', 6, 25),
  ('d1000000-0000-4000-8000-000000000021', 'b1000000-0000-4000-8000-000000000007', 'FINISH_SMALL_COMMITMENT', 'Hold the Line', 'Finish one small commitment before changing direction.', 'PERSEVERANCE', 6, 25),
  ('d1000000-0000-4000-8000-000000000022', 'b1000000-0000-4000-8000-000000000008', 'RETURN_TODAY', 'Begin Again', 'Resume one abandoned good habit today for at least five minutes.', 'PERSEVERANCE', 9, 35),
  ('d1000000-0000-4000-8000-000000000023', 'b1000000-0000-4000-8000-000000000008', 'PSALM_OF_HOPE', 'Answer the Whisper', 'Read a Psalm of hope and write one sentence of truth.', 'FAITH', 6, 25),
  ('d1000000-0000-4000-8000-000000000024', 'b1000000-0000-4000-8000-000000000008', 'ASK_FOR_SUPPORT', 'Call Reinforcements', 'Ask a trusted person for prayer, encouragement, or accountability.', 'COURAGE', 7, 30),
  ('d1000000-0000-4000-8000-000000000025', 'b1000000-0000-4000-8000-000000000009', 'VERIFY_OR_SILENCE', 'Lock the Rumor Chest', 'Do not repeat the story unless it is true, necessary, and charitable.', 'WISDOM', 6, 25),
  ('d1000000-0000-4000-8000-000000000026', 'b1000000-0000-4000-8000-000000000009', 'SPEAK_GOOD', 'Replace It with Honor', 'Say one sincere good thing about the person instead.', 'CHARITY', 7, 30),
  ('d1000000-0000-4000-8000-000000000027', 'b1000000-0000-4000-8000-000000000009', 'EXAMINE_MOTIVE', 'Check the Mirror', 'Write why you wanted to share the information before speaking.', 'HUMILITY', 6, 25),
  ('d1000000-0000-4000-8000-000000000028', 'b1000000-0000-4000-8000-000000000010', 'WAIT_24_HOURS', 'The Discernment Delay', 'Wait 24 hours before making a nonessential purchase.', 'DISCIPLINE', 7, 30),
  ('d1000000-0000-4000-8000-000000000029', 'b1000000-0000-4000-8000-000000000010', 'NEED_TEST', 'Need, Use, Cost', 'Write what happens if you do not buy it, how often it will be used, and its full cost.', 'WISDOM', 6, 25),
  ('d1000000-0000-4000-8000-000000000030', 'b1000000-0000-4000-8000-000000000010', 'GIVE_ITEM', 'Open the Storehouse', 'Donate or give away one useful item in good condition.', 'CHARITY', 7, 30),
  ('d1000000-0000-4000-8000-000000000031', 'b1000000-0000-4000-8000-000000000011', 'FACTS_VALUES_NEXT_STEP', 'Clear the Fog', 'Write the known facts, the value involved, and the next reasonable step.', 'WISDOM', 8, 35),
  ('d1000000-0000-4000-8000-000000000032', 'b1000000-0000-4000-8000-000000000011', 'PRAY_AND_DECIDE', 'Pray, Then Move', 'Pray briefly, choose among morally good options, and set a deadline.', 'FAITH', 6, 25),
  ('d1000000-0000-4000-8000-000000000033', 'b1000000-0000-4000-8000-000000000011', 'SMALL_COMMITMENT', 'Cross the Threshold', 'Make one small reversible commitment today.', 'COURAGE', 6, 25),
  ('d1000000-0000-4000-8000-000000000034', 'b1000000-0000-4000-8000-000000000012', 'LEAVE_TRIGGER', 'Exit the Room', 'Immediately close the content and physically leave the triggering environment.', 'PURITY', 8, 35),
  ('d1000000-0000-4000-8000-000000000035', 'b1000000-0000-4000-8000-000000000012', 'CONTACT_ACCOUNTABILITY', 'Break the Secrecy', 'Contact a trusted accountability person with a simple request for support.', 'COURAGE', 7, 30),
  ('d1000000-0000-4000-8000-000000000036', 'b1000000-0000-4000-8000-000000000012', 'DEVICE_BOUNDARY', 'Guard the Gate', 'Move the device out of the private space and enable content restrictions.', 'DISCIPLINE', 7, 30)
on conflict (id) do update
set
  demon_id = excluded.demon_id,
  code = excluded.code,
  name = excluded.name,
  challenge = excluded.challenge,
  reward_virtue_code = excluded.reward_virtue_code,
  virtue_increase = excluded.virtue_increase,
  demon_damage = excluded.demon_damage;

insert into competition.demon_defeat_rewards (demon_id, virtue_code, virtue_increase, xp_reward)
values
  ('b1000000-0000-4000-8000-000000000001', 'DISCIPLINE', 10, 100),
  ('b1000000-0000-4000-8000-000000000002', 'DISCIPLINE', 10, 100),
  ('b1000000-0000-4000-8000-000000000003', 'CHARITY', 10, 110),
  ('b1000000-0000-4000-8000-000000000004', 'HUMILITY', 10, 120),
  ('b1000000-0000-4000-8000-000000000005', 'DISCIPLINE', 9, 100),
  ('b1000000-0000-4000-8000-000000000006', 'CHARITY', 10, 105),
  ('b1000000-0000-4000-8000-000000000007', 'COURAGE', 10, 115),
  ('b1000000-0000-4000-8000-000000000008', 'PERSEVERANCE', 12, 125),
  ('b1000000-0000-4000-8000-000000000009', 'CHARITY', 10, 110),
  ('b1000000-0000-4000-8000-000000000010', 'CHARITY', 10, 110),
  ('b1000000-0000-4000-8000-000000000011', 'WISDOM', 11, 120),
  ('b1000000-0000-4000-8000-000000000012', 'PURITY', 12, 130)
on conflict (demon_id) do update
set
  virtue_code = excluded.virtue_code,
  virtue_increase = excluded.virtue_increase,
  xp_reward = excluded.xp_reward;

insert into competition.badge_requirement_definitions (
  id,
  badge_id,
  requirement_type,
  required_value,
  description,
  rules,
  display_order
)
values
  ('e1000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000005', 'daily_honesty_reflection', 7, 'Complete seven daily honesty reflections.', '{"virtue":"truth"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000006', 'prayer_days', 7, 'Seven days of prayer.', '{"virtue":"faith"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000003', '80000000-0000-4000-8000-000000000006', 'scripture_plan_completed', 1, 'One completed Scripture plan.', '{"virtue":"faith"}'::jsonb, 2),
  ('e1000000-0000-4000-8000-000000000004', '80000000-0000-4000-8000-000000000006', 'trust_act_during_difficulty', 1, 'One act of trust during difficulty.', '{"virtue":"faith"}'::jsonb, 3),
  ('e1000000-0000-4000-8000-000000000005', '80000000-0000-4000-8000-000000000007', 'scripture_reading_sessions', 10, 'Complete ten Scripture reading sessions.', '{"virtue":"wisdom"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000006', '80000000-0000-4000-8000-000000000008', 'daily_prayer_streak', 14, 'Maintain a fourteen-day prayer streak.', '{"virtue":"hope"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000007', '80000000-0000-4000-8000-000000000009', 'service_acts', 5, 'Complete five acts of service.', '{"virtue":"readiness"}'::jsonb, 1),
  ('e1000000-0000-4000-8000-000000000008', '80000000-0000-4000-8000-000000000010', 'daily_rule_of_life_streak', 21, 'Maintain a twenty-one-day rule-of-life streak.', '{"virtue":"righteousness"}'::jsonb, 1)
on conflict (id) do update
set
  badge_id = excluded.badge_id,
  requirement_type = excluded.requirement_type,
  required_value = excluded.required_value,
  description = excluded.description,
  rules = excluded.rules,
  display_order = excluded.display_order;

-- These activity-based badges predate the requirement-rule system. Seed their
-- canonical requirements explicitly so the seed remains valid when it is run
-- against an already-migrated database as well as after a clean reset.
insert into competition.badge_requirement_definitions (
  badge_id,
  requirement_type,
  required_value,
  description,
  rules,
  display_order,
  translations
)
select
  badge.id,
  source.requirement_type,
  source.required_value,
  source.description,
  source.rules,
  source.display_order,
  source.translations
from (
  values
    ('FIRST_ROSARY', 'rosary_completed', 1, 'Pray your first complete rosary.', '{}'::jsonb, 1,
      jsonb_build_object('es', jsonb_build_object('description', 'Reza tu primer rosario completo.'))),
    ('SCRIPTURE_SEEKER', 'scripture_reading_sessions', 5, 'Complete five Scripture reading sessions.', '{}'::jsonb, 1,
      jsonb_build_object('es', jsonb_build_object('description', 'Completa cinco sesiones de lectura de la Escritura.')))
) as source(code, requirement_type, required_value, description, rules, display_order, translations)
join competition.badge_definitions badge on badge.code = source.code
on conflict (badge_id, display_order) do update
set
  requirement_type = excluded.requirement_type,
  required_value = excluded.required_value,
  description = excluded.description,
  rules = excluded.rules,
  translations = excluded.translations;

insert into competition.badge_requirement_activity_rules (
  badge_requirement_id,
  activity_code,
  progress_mode,
  metadata_filter
)
values
  ('e1000000-0000-4000-8000-000000000001', 'HONESTY_REFLECTION', 'distinct_days', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000002', 'PRAYER', 'distinct_days', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000003', 'SCRIPTURE', 'activity_quantity', '{"planCompleted":true}'::jsonb),
  ('e1000000-0000-4000-8000-000000000004', 'TRUST_ACT', 'activity_quantity', '{"duringDifficulty":true}'::jsonb),
  ('e1000000-0000-4000-8000-000000000005', 'SCRIPTURE', 'activity_quantity', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000006', 'PRAYER', 'consecutive_days', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000007', 'SERVICE', 'activity_quantity', '{}'::jsonb),
  ('e1000000-0000-4000-8000-000000000008', 'RULE_OF_LIFE', 'consecutive_days', '{}'::jsonb)
on conflict (badge_requirement_id) do update
set
  activity_code = excluded.activity_code,
  progress_mode = excluded.progress_mode,
  metadata_filter = excluded.metadata_filter;

insert into competition.badge_requirement_activity_rules (
  badge_requirement_id,
  activity_code,
  progress_mode,
  metadata_filter
)
select
  requirement.id,
  source.activity_code,
  source.progress_mode,
  source.metadata_filter
from (
  values
    ('FIRST_ROSARY', 'rosary_completed', 'ROSARY', 'activity_quantity', '{}'::jsonb),
    ('SCRIPTURE_SEEKER', 'scripture_reading_sessions', 'SCRIPTURE', 'activity_quantity', '{}'::jsonb)
) as source(badge_code, requirement_type, activity_code, progress_mode, metadata_filter)
join competition.badge_definitions badge on badge.code = source.badge_code
join competition.badge_requirement_definitions requirement
  on requirement.badge_id = badge.id
  and requirement.requirement_type = source.requirement_type
on conflict (badge_requirement_id) do update
set
  activity_code = excluded.activity_code,
  progress_mode = excluded.progress_mode,
  metadata_filter = excluded.metadata_filter;

insert into competition.demon_defense_activity_rules (
  defense_id,
  activity_code,
  metadata_filter
)
values
  ('d1000000-0000-4000-8000-000000000003', 'SCRIPTURE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000006', 'SERVICE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000008', 'PRAYER', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000023', 'SCRIPTURE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000020', 'PRAYER', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000030', 'SERVICE', '{}'::jsonb),
  ('d1000000-0000-4000-8000-000000000032', 'PRAYER', '{}'::jsonb)
on conflict (defense_id) do update
set
  activity_code = excluded.activity_code,
  metadata_filter = excluded.metadata_filter;

insert into competition.point_rules (
  id,
  code,
  activity_code,
  name,
  description,
  points,
  daily_limit,
  weekly_limit,
  effective_from,
  is_active
)
values
  ('30000000-0000-4000-8000-000000000001', 'ROSARY_COMPLETE', 'ROSARY', 'Rosary completed', 'Points for a complete rosary.', 50, 3, 15, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000002', 'SCRIPTURE_SESSION', 'SCRIPTURE', 'Scripture session', 'Points for reading Scripture.', 20, 5, 25, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000003', 'PERSONAL_PRAYER', 'PRAYER', 'Personal prayer', 'Points for personal prayer.', 15, 5, 30, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000004', 'ADORATION_SESSION', 'ADORATION', 'Adoration session', 'Points for Eucharistic adoration.', 40, 2, 8, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000005', 'SERVICE_ACT', 'SERVICE', 'Act of service', 'Points for serving another person.', 60, 3, 12, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000006', 'FASTING_OFFERING', 'FASTING', 'Fasting offering', 'Points for a voluntary fast.', 35, 1, 3, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000007', 'HONESTY_REFLECTION', 'HONESTY_REFLECTION', 'Honesty reflection', 'Points for a truthful daily reflection.', 10, 1, 7, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000008', 'TRUST_ACT', 'TRUST_ACT', 'Act of trust', 'Points for acting in trust during difficulty.', 25, 1, 5, now() - interval '1 year', true),
  ('30000000-0000-4000-8000-000000000009', 'RULE_OF_LIFE', 'RULE_OF_LIFE', 'Rule of life completed', 'Points for completing a daily rule of life.', 30, 1, 7, now() - interval '1 year', true)
on conflict (id) do update
set
  code = excluded.code,
  activity_code = excluded.activity_code,
  name = excluded.name,
  description = excluded.description,
  points = excluded.points,
  daily_limit = excluded.daily_limit,
  weekly_limit = excluded.weekly_limit,
  effective_from = excluded.effective_from,
  is_active = excluded.is_active;

insert into competition.challenge_definitions (
  id,
  code,
  title,
  description,
  challenge_type,
  activity_code,
  target_quantity,
  xp_reward,
  badge_reward_id,
  difficulty,
  assignment_weight,
  rules,
  icon_url,
  is_active
)
values
  ('60000000-0000-4000-8000-000000000001', 'DAILY_ROSARY', 'Daily Rosary', 'Pray one complete rosary today.', 'daily', 'ROSARY', 1, 50, '80000000-0000-4000-8000-000000000001', 'normal', 100, '{"reset":"daily"}'::jsonb, '/challenges/rosary.png', true),
  ('60000000-0000-4000-8000-000000000002', 'DAILY_SCRIPTURE', 'Daily Scripture', 'Complete one Scripture reading today.', 'daily', 'SCRIPTURE', 1, 25, null, 'easy', 120, '{"minimumDurationSeconds":300}'::jsonb, '/challenges/scripture.png', true),
  ('60000000-0000-4000-8000-000000000003', 'WEEKLY_SERVICE', 'Serve Your Neighbor', 'Complete three acts of service this week.', 'weekly', 'SERVICE', 3, 150, '80000000-0000-4000-8000-000000000004', 'hard', 60, '{"reset":"weekly"}'::jsonb, '/challenges/service.png', true)
on conflict (id) do update
set
  code = excluded.code,
  title = excluded.title,
  description = excluded.description,
  challenge_type = excluded.challenge_type,
  activity_code = excluded.activity_code,
  target_quantity = excluded.target_quantity,
  xp_reward = excluded.xp_reward,
  badge_reward_id = excluded.badge_reward_id,
  difficulty = excluded.difficulty,
  assignment_weight = excluded.assignment_weight,
  rules = excluded.rules,
  icon_url = excluded.icon_url,
  is_active = excluded.is_active;

-- ---------------------------------------------------------------------------

-- Examination questions are curated application data. The API deliberately
-- selects from this table deterministically; no question is manufactured at
-- request time.
with source as (
  select *
  from jsonb_to_recordset($questions$
[
  {"category":"single","title":"Faith","commandment":1,"type":"mortal","question":"Have I denied or abandoned the Catholic faith (apostasy)?","description":"Apostasy is the total repudiation of the Christian faith (CCC 2089). It is grave matter because it rejects God’s revelation and severs communion with the Church.","counsels":["Return through Confession and a profession of faith.","Study the core teachings you rejected.","Seek guidance from a priest or mentor."],"prevention":["Daily Scripture (10–15 minutes)","Weekly Catechism reading","Stay connected to a parish community"],"saints":["St. Augustine","St. John Henry Newman"]},
  {"category":"single","title":"Faith","commandment":1,"type":"mortal","question":"Have I seriously doubted or rejected a doctrine of the Church (heresy)?","description":"Heresy is obstinate post-baptismal denial of a truth to be believed with divine faith (CCC 2089).","counsels":["Clarify what you rejected and why.","Seek truth with humility, not pride.","Bring intellectual doubts to someone faithful."],"prevention":["Structured catechesis","Avoid anti-faith media","Ask questions early"],"saints":["St. Thomas Aquinas"]},
  {"category":"single","title":"Faith","commandment":1,"type":"mortal","question":"Have I engaged in superstition, horoscopes, or occult practices?","description":"All forms of divination and occult practices reject trust in God (CCC 2116–2117).","counsels":["Renounce explicitly in prayer.","Remove all related objects/apps.","Confess and replace with trust in God."],"prevention":["Pray 'Jesus I trust in You'","Avoid occult media","Use Scripture for guidance"],"saints":["St. Benedict","St. Cyprian"]},
  {"category":"single","title":"Hope","commandment":1,"type":"mortal","question":"Have I fallen into despair, believing God cannot forgive me?","description":"Despair rejects God's mercy and salvation (CCC 2091).","counsels":["God’s mercy is infinite.","Confess and trust Him again."],"prevention":["Divine Mercy devotion","Avoid isolation"],"saints":["St. Faustina"]},
  {"category":"single","title":"Hope","commandment":1,"type":"mortal","question":"Have I presumed God's mercy without repentance?","description":"Presumption expects forgiveness without conversion (CCC 2092).","counsels":["Repent sincerely.","Avoid excusing sin."],"prevention":["Regular Confession","Daily examen"],"saints":["St. Thérèse"]},
  {"category":"single","title":"Love of God","commandment":3,"type":"mortal","question":"Have I missed Sunday Mass without serious reason?","description":"Missing Mass deliberately is grave (CCC 2181).","counsels":["Make Mass a priority.","Confess if missed deliberately."],"prevention":["Plan ahead","Set reminders"],"saints":["St. John Paul II"]},
  {"category":"single","title":"Prayer Life","commandment":1,"type":"grave","question":"Have I neglected daily prayer?","description":"Prayer is necessary for spiritual life (CCC 2744).","counsels":["Start with 5–10 minutes daily."],"prevention":["Morning + night routine"],"saints":["St. Teresa of Avila"]},
  {"category":"single","title":"Chastity","commandment":6,"type":"mortal","question":"Have I engaged in fornication?","description":"Sex outside marriage is gravely sinful (CCC 2353).","counsels":["End sinful relationships.","Seek accountability."],"prevention":["Avoid private situations","Set boundaries"],"saints":["St. Maria Goretti"]},
  {"category":"single","title":"Chastity","commandment":6,"type":"mortal","question":"Have I viewed pornography?","description":"Pornography violates dignity and purity (CCC 2354).","counsels":["Confess immediately.","Install blockers."],"prevention":["Avoid triggers","Stay in public environments"],"saints":["St. Augustine"]},
  {"category":"single","title":"Chastity","commandment":6,"type":"mortal","question":"Have I committed masturbation?","description":"Masturbation is disordered use of sexuality (CCC 2352).","counsels":["Confess and seek discipline."],"prevention":["Cold showers","Exercise","Avoid idleness"],"saints":["St. John Bosco"]},
  {"category":"married","title":"Chastity","commandment":6,"type":"mortal","question":"Have I committed adultery?","description":"Adultery violates the marriage covenant (CCC 2380).","counsels":["End the relationship immediately.","Seek reconciliation."],"prevention":["Avoid emotional attachments outside marriage"],"saints":["St. Joseph"]},
  {"category":"married","title":"Love of Neighbor","commandment":5,"type":"mortal","question":"Have I been abusive toward my spouse or children?","description":"Abuse violates dignity and charity (CCC 2302).","counsels":["Seek help immediately.","Repent sincerely."],"prevention":["Anger management","Counseling"],"saints":["St. Francis de Sales"]},
  {"category":"married","title":"Justice","commandment":7,"type":"mortal","question":"Have I failed to provide for my family?","description":"Neglecting family responsibilities is unjust (CCC 2211).","counsels":["Take responsibility seriously."],"prevention":["Budgeting","Work discipline"],"saints":["St. Joseph"]},
  {"category":"religious","title":"Obedience","commandment":4,"type":"mortal","question":"Have I disobeyed legitimate authority?","description":"Religious obedience imitates Christ (CCC 915).","counsels":["Practice humility."],"prevention":["Trust superiors"],"saints":["St. Ignatius"]},
  {"category":"religious","title":"Chastity","commandment":6,"type":"mortal","question":"Have I violated my vow of chastity?","description":"Consecrated chastity is total dedication to God (CCC 2349).","counsels":["Return to grace immediately."],"prevention":["Custody of the eyes","Prayer discipline"],"saints":["St. Clare"]},
  {"category":"religious","title":"Poverty","commandment":1,"type":"grave","question":"Have I been attached to material goods?","description":"Poverty calls for detachment (CCC 2544).","counsels":["Live simply."],"prevention":["Minimalism","Generosity"],"saints":["St. Francis"]},
  {"category":"single","title":"Reverence for God","commandment":2,"type":"mortal","question":"Have I taken the Lord’s name in vain seriously or blasphemed?","description":"Blasphemy is speaking against God with hatred, reproach, or defiance and is gravely sinful (CCC 2148). It violates reverence owed to God’s name.","counsels":["Acknowledge the seriousness of your words.","Repair by acts of reverence (prayer, adoration)."],"prevention":["Replace profanity with short prayers","Avoid environments where blasphemy is normalized"],"saints":["St. Benedict"]},
  {"category":"single","title":"Truth","commandment":8,"type":"mortal","question":"Have I committed serious lying or deception that harmed others?","description":"Lying is speaking falsehood with intent to deceive (CCC 2482). Grave lies cause serious harm and are mortal.","counsels":["Repair the harm done.","Confess clearly."],"prevention":["Practice radical honesty","Pause before speaking"],"saints":["St. Thomas More"]},
  {"category":"single","title":"Justice","commandment":7,"type":"mortal","question":"Have I stolen something of significant value?","description":"Theft violates justice and requires restitution (CCC 2408–2412).","counsels":["Return what you took.","Make restitution."],"prevention":["Respect others’ property","Avoid rationalizing theft"],"saints":["St. Zacchaeus"]},
  {"category":"single","title":"Charity","commandment":5,"type":"mortal","question":"Have I hated someone or wished serious harm upon them?","description":"Hatred of neighbor is contrary to charity and can be gravely sinful (CCC 2303).","counsels":["Pray for the person.","Choose forgiveness."],"prevention":["Practice empathy","Pray daily for enemies"],"saints":["St. Stephen"]},
  {"category":"single","title":"Charity","commandment":5,"type":"mortal","question":"Have I refused to forgive someone who seriously hurt me?","description":"Refusal to forgive blocks God’s mercy (CCC 2840).","counsels":["Forgiveness is a choice.","Release resentment."],"prevention":["Daily prayer for healing","Practice mercy"],"saints":["St. Maria Goretti"]},
  {"category":"single","title":"Temperance","commandment":5,"type":"mortal","question":"Have I abused alcohol to the point of drunkenness?","description":"Drunkenness impairs reason and dignity (CCC 2290).","counsels":["Seek accountability.","Reduce or eliminate use."],"prevention":["Avoid excessive environments","Know your limits"],"saints":["St. Monica"]},
  {"category":"single","title":"Temperance","commandment":5,"type":"mortal","question":"Have I used drugs or substances that harm my body or mind?","description":"Drug use is a grave offense against health and life (CCC 2291).","counsels":["Seek help immediately.","Confess sincerely."],"prevention":["Avoid harmful environments","Stay accountable"],"saints":["St. Maximilian Kolbe"]},
  {"category":"single","title":"Chastity","commandment":6,"type":"mortal","question":"Have I deliberately entertained lustful thoughts?","description":"Lust is disordered desire for sexual pleasure (CCC 2351).","counsels":["Reject thoughts immediately.","Redirect attention."],"prevention":["Custody of eyes","Mental discipline"],"saints":["St. Joseph"]},
  {"category":"single","title":"Chastity","commandment":6,"type":"grave","question":"Have I placed myself in near occasions of sexual sin?","description":"Knowingly entering temptation risks grave sin (CCC 2119).","counsels":["Identify triggers.","Remove them."],"prevention":["Avoid isolation","Set boundaries"],"saints":["St. Anthony of the Desert"]},
  {"category":"single","title":"Love of Neighbor","commandment":8,"type":"mortal","question":"Have I seriously damaged someone’s reputation (calumny or detraction)?","description":"Revealing faults unjustly harms others (CCC 2477).","counsels":["Repair the damage.","Speak truth with charity."],"prevention":["Avoid gossip","Think before speaking"],"saints":["St. Francis de Sales"]},
  {"category":"single","title":"Justice","commandment":7,"type":"mortal","question":"Have I cheated in school, work, or business?","description":"Fraud and cheating violate justice (CCC 2409).","counsels":["Make restitution.","Be honest going forward."],"prevention":["Integrity mindset","Avoid shortcuts"],"saints":["St. Joseph"]},
  {"category":"single","title":"Faith","commandment":1,"type":"mortal","question":"Have I publicly denied my faith out of fear or shame?","description":"Failing to witness to Christ can be grave (CCC 1816).","counsels":["Repent and stand firm.","Strengthen courage."],"prevention":["Practice small acts of witness","Stay rooted in truth"],"saints":["St. Peter"]},
  {"category":"single","title":"Humility","commandment":1,"type":"grave","question":"Have I acted out of pride, placing myself above God or others?","description":"Pride is the root of sin (CCC 1866).","counsels":["Practice humility.","Serve others."],"prevention":["Daily humility reflection","Acts of service"],"saints":["St. Augustine"]},
  {"category":"single","title":"Sloth","commandment":1,"type":"grave","question":"Have I neglected my responsibilities out of laziness?","description":"Sloth is spiritual and physical laziness (CCC 2733).","counsels":["Build discipline.","Start small."],"prevention":["Structured schedule","Accountability"],"saints":["St. Benedict"]},
  {"category":"single","title":"Charity","commandment":5,"type":"grave","question":"Have I ignored the needs of the poor or suffering?","description":"Neglecting charity is sinful (CCC 2447).","counsels":["Be generous.","Serve actively."],"prevention":["Give regularly","Volunteer"],"saints":["St. Mother Teresa"]},
  {"category":"single","title":"Justice","commandment":7,"type":"grave","question":"Have I wasted money irresponsibly or been overly materialistic?","description":"Attachment to wealth leads away from God (CCC 2424).","counsels":["Simplify life.","Prioritize God."],"prevention":["Budget wisely","Practice detachment"],"saints":["St. Francis"]},
  {"category":"single","title":"Temperance","commandment":5,"type":"grave","question":"Have I been gluttonous or lacked self-control?","description":"Gluttony is disordered consumption (CCC 1866).","counsels":["Practice moderation."],"prevention":["Fasting","Discipline"],"saints":["St. Thomas Aquinas"]},
  {"category":"single","title":"Love of Neighbor","commandment":8,"type":"grave","question":"Have I judged others rashly without sufficient evidence?","description":"Rash judgment violates charity (CCC 2478).","counsels":["Assume good intentions."],"prevention":["Pause before judging"],"saints":["St. Ignatius"]},
  {"category":"single","title":"Faith","commandment":1,"type":"grave","question":"Have I placed relationships, career, or success above God?","description":"Idolatry places created things above God (CCC 2113).","counsels":["Reorder priorities."],"prevention":["Daily prayer","Spiritual discipline"],"saints":["St. Francis"]},
  {"category":"single","title":"Prayer Life","commandment":1,"type":"grave","question":"Have I ignored God’s call in my life or failed to discern my vocation?","description":"Each person has a calling from God (CCC 2232).","counsels":["Pray for clarity.","Seek guidance."],"prevention":["Spiritual direction","Silence and prayer"],"saints":["St. John Paul II"]}
]
$questions$::jsonb) as entry(
  category text,
  title text,
  commandment smallint,
  type text,
  question text,
  description text,
  counsels jsonb,
  prevention jsonb,
  saints jsonb
)
)
insert into app.examination_of_conscience_questions (
  category, title, commandment, severity, question, description,
  counsels, prevention, saints, is_active
)
select
  category, title, commandment, type, question, description,
  array(select jsonb_array_elements_text(counsels)),
  array(select jsonb_array_elements_text(prevention)),
  array(select jsonb_array_elements_text(saints)),
  true
from source
on conflict (question) do update set
  category = excluded.category,
  title = excluded.title,
  commandment = excluded.commandment,
  severity = excluded.severity,
  description = excluded.description,
  counsels = excluded.counsels,
  prevention = excluded.prevention,
  saints = excluded.saints,
  is_active = true,
  updated_at = now();

with source as (
  select *
  from jsonb_to_recordset($questions$
[
  {"category":"religious","title":"Obedience","commandment":4,"type":"mortal","question":"Have I persistently refused to obey my legitimate superiors in matters of community life?","description":"Religious obedience is a participation in Christ's own obedience and a vow freely made to God (CCC 915, 2103).","counsels":["Examine the root cause of your resistance — pride, fear, or legitimate concern.","Speak openly with your superior about your struggles.","Recommit your will to God through your vow."],"prevention":["Daily renewal of vows in morning prayer","Regular spiritual direction","Meditate on Christ's obedience in Gethsemane"],"saints":["St. Ignatius of Loyola","St. Faustina"]},
  {"category":"religious","title":"Chastity","commandment":6,"type":"mortal","question":"Have I entertained romantic or sexual fantasies, or formed an exclusive emotional attachment?","description":"Consecrated chastity requires undivided love for God; exclusive attachments undermine this gift (CCC 2349, 916).","counsels":["Bring the attachment to your spiritual director immediately.","Set firm boundaries with the person involved.","Redirect your affection toward Christ through prayer."],"prevention":["Custody of the eyes and imagination","Avoid private one-on-one meetings that create intimacy","Nurture friendships within healthy community settings"],"saints":["St. Clare of Assisi","St. Maria Goretti"]},
  {"category":"religious","title":"Poverty","commandment":10,"type":"grave","question":"Have I secretly kept money, possessions, or privileges for myself against my community's rule?","description":"The vow of poverty calls for detachment from material goods and sharing all things in common (CCC 2544–2545).","counsels":["Surrender hidden items or funds to your superior.","Confess attachments honestly.","Embrace simplicity as a path to freedom."],"prevention":["Regular inventory of personal belongings","Ask permission before acquiring anything","Meditate on Christ's poverty in the manger and on the cross"],"saints":["St. Francis of Assisi"]},
  {"category":"religious","title":"Prayer Life","commandment":1,"type":"grave","question":"Have I habitually skipped the Liturgy of the Hours, community prayer, or personal meditation?","description":"Prayer is the foundation of consecrated life; neglecting it leads to spiritual dryness and loss of vocation (CCC 2691, 2744).","counsels":["Return to your prayer schedule starting today.","Bring your dryness to spiritual direction.","Start small if overwhelmed — even five minutes of silent presence."],"prevention":["Fixed prayer schedule with community accountability","Treat prayer times as sacred appointments","Vary prayer forms to combat routine (lectio, adoration, Rosary)"],"saints":["St. Teresa of Avila","St. John of the Cross"]},
  {"category":"religious","title":"Truth","commandment":8,"type":"mortal","question":"Have I caused scandal by living contrary to the vows I profess publicly?","description":"Scandal leads others to sin and is especially grave when caused by those who teach or model the faith (CCC 2284–2285).","counsels":["Acknowledge the harm your witness has caused.","Confess and make amends where possible.","Renew your commitment to authentic witness."],"prevention":["Live as if your actions are always observed — because they are by God","Regular examen focused on public witness","Ask a trusted peer for honest feedback"],"saints":["St. Peter","St. John Vianney"]},
  {"category":"religious","title":"Humility","commandment":1,"type":"grave","question":"Have I acted out of pride in my ministry, seeking recognition or control?","description":"Pride in ministry turns service into self-promotion and is contrary to the spirit of Christ the servant (CCC 1831, 2540).","counsels":["Offer your ministry back to God each morning.","Accept hidden tasks without complaint.","Celebrate others' gifts without envy."],"prevention":["Begin each ministry task with a prayer of surrender","Seek the lowest place at gatherings","Fast from talking about your accomplishments"],"saints":["St. Thérèse of Lisieux","St. Vincent de Paul"]},
  {"category":"religious","title":"Charity","commandment":5,"type":"grave","question":"Have I been uncharitable, critical, or cold toward members of my religious community?","description":"Community life demands patient charity; persistent unkindness wounds the Body of Christ (CCC 1822, 2447).","counsels":["Apologize to anyone you've hurt.","Practice small acts of kindness toward the person you find most difficult.","Examine whether your criticism reflects projections of your own faults."],"prevention":["Daily prayer for each community member by name","Speak about others only what you would say to their face","Practice the 'little way' of small, hidden sacrifices"],"saints":["St. Thérèse of Lisieux"]},
  {"category":"religious","title":"Justice","commandment":4,"type":"mortal","question":"Have I misused authority over those entrusted to my care?","description":"Authority in religious life must serve, not dominate; misuse is a grave violation of justice (CCC 2235–2236).","counsels":["Examine how you exercise power — is it for others or for yourself?","Seek forgiveness from those you've mistreated.","Submit to periodic reviews of your leadership."],"prevention":["Model servant leadership after Christ washing feet","Maintain open channels for feedback from those you lead","Regular reading on the spirituality of leadership"],"saints":["St. Benedict","St. Pope Gregory the Great"]},
  {"category":"religious","title":"Love of God","commandment":3,"type":"mortal","question":"Have I celebrated the Eucharist or sacraments routinely, without reverence or interior devotion?","description":"The Eucharist demands interior participation; habitual irreverence diminishes its transformative power (CCC 1387–1388).","counsels":["Prepare for Mass with silent prayer beforehand.","Renew your awareness of Christ's Real Presence.","Make a thanksgiving after receiving Communion."],"prevention":["Arrive 10 minutes early for silence","Read the day's readings beforehand","Monthly day of recollection focused on the Eucharist"],"saints":["St. Peter Julian Eymard","St. Padre Pio"]},
  {"category":"religious","title":"Obedience","commandment":4,"type":"grave","question":"Have I murmured against or undermined my superior's decisions behind their back?","description":"Murmuring and gossip against authority erode community trust and violate the spirit of obedience (CCC 2477, 2103).","counsels":["Bring your disagreements directly to your superior.","Stop participating in circles of complaint.","Pray for your superiors daily."],"prevention":["Practice the discipline of direct communication","Offer a Hail Mary when tempted to complain","Journal frustrations privately before speaking"],"saints":["St. Ignatius of Loyola"]},
  {"category":"religious","title":"Poverty","commandment":7,"type":"grave","question":"Have I lived extravagantly or sought unnecessary comforts contrary to my vow?","description":"Religious poverty witnesses to detachment from worldly goods; indulgence contradicts this witness (CCC 2544–2546).","counsels":["Simplify your living space and habits.","Return unnecessary items to the community.","Embrace discomfort as a share in Christ's poverty."],"prevention":["Periodic simplicity audit of your room and possessions","Ask before buying: 'Do I need this, or want this?'","Volunteer for the less comfortable assignments"],"saints":["St. Francis of Assisi","Bl. Charles de Foucauld"]},
  {"category":"religious","title":"Truth","commandment":8,"type":"grave","question":"Have I been hypocritical — presenting a holy image externally while living differently in private?","description":"Hypocrisy is a form of lying that gravely harms one's own soul and others' trust in the faith (CCC 2468, 2505).","counsels":["Be honest in spiritual direction about your interior life.","Let your private life match your public witness.","Confess not just actions but patterns of duplicity."],"prevention":["Daily examen with brutal honesty","Cultivate one trusted confidant who sees the real you","Pray 'Lord, let me be the same person in public and in private'"],"saints":["St. John Vianney"]},
  {"category":"religious","title":"Temperance","commandment":5,"type":"grave","question":"Have I been intemperate with food, drink, or digital media in a way that harms my spiritual life?","description":"Temperance moderates desires and is essential for religious witness; excess dulls the spiritual senses (CCC 1809, 2290).","counsels":["Fast or abstain as a concrete act of self-denial.","Set strict limits on media and entertainment consumption.","Replace indulgent habits with prayer or service."],"prevention":["Follow your community's fasting practices faithfully","No screens after evening prayer","Weekly fasting beyond the minimum required"],"saints":["St. Benedict","St. John the Baptist"]},
  {"category":"religious","title":"Charity","commandment":5,"type":"mortal","question":"Have I gossiped about or detracted from the reputation of fellow religious?","description":"Detraction unjustly harms another's reputation and wounds community life (CCC 2477, 2479).","counsels":["Apologize to anyone whose reputation you damaged.","Repair the harm by speaking well of them to the same audience.","Commit to speaking only what is true, necessary, and kind."],"prevention":["Apply the 'three gates' test: Is it true? Is it necessary? Is it kind?","Leave conversations that turn to gossip","Pray for those you are tempted to criticize"],"saints":["St. Francis de Sales","St. Philip Neri"]},
  {"category":"religious","title":"Zeal","commandment":1,"type":"grave","question":"Have I become complacent in my vocation, going through the motions without love?","description":"Lukewarmness in consecrated life is spiritual acedia — a weariness that refuses God's joy (CCC 2094, 2733).","counsels":["Renew your vows intentionally and prayerfully.","Ask God to rekindle your first love.","Seek a new apostolate or ministry to revive your zeal."],"prevention":["Annual retreat focused on your vocation story","Serve in a new capacity periodically","Read the lives of saints who shared your charism"],"saints":["St. Teresa of Avila","St. Ignatius of Loyola"]},
  {"category":"religious","title":"Justice","commandment":7,"type":"grave","question":"Have I used community resources selfishly or wasted what belongs to the community?","description":"Community goods are held in trust; wasting them violates justice and the common good (CCC 2404–2405).","counsels":["Return or replace what you misused.","Discuss resource use openly in community meetings.","Practice gratitude for what is provided."],"prevention":["Treat community property as sacred","Ask permission before using shared resources for personal needs","Volunteer for stewardship duties"],"saints":["St. Basil the Great"]},
  {"category":"religious","title":"Faith","commandment":1,"type":"grave","question":"Have I allowed intellectual pride to distance me from simple, childlike faith?","description":"Intellectual pride can replace trust in God with trust in one's own understanding (CCC 2088, 1831).","counsels":["Approach Scripture and prayer with a beginner's heart.","Submit your intellect to the faith of the Church.","Seek wisdom, not just knowledge."],"prevention":["Pray the Litany of Humility regularly","Study under obedience, not solely personal interest","Spend time with simple, faith-filled people"],"saints":["St. Thomas Aquinas","St. Thérèse of Lisieux"]}
]
$questions$::jsonb) as entry(
  category text,
  title text,
  commandment smallint,
  type text,
  question text,
  description text,
  counsels jsonb,
  prevention jsonb,
  saints jsonb
)
)
insert into app.examination_of_conscience_questions (
  category, title, commandment, severity, question, description,
  counsels, prevention, saints, is_active
)
select category, title, commandment, type, question, description,
  array(select jsonb_array_elements_text(counsels)),
  array(select jsonb_array_elements_text(prevention)),
  array(select jsonb_array_elements_text(saints)), true
from source
on conflict (question) do update set
  category = excluded.category,
  title = excluded.title,
  commandment = excluded.commandment,
  severity = excluded.severity,
  description = excluded.description,
  counsels = excluded.counsels,
  prevention = excluded.prevention,
  saints = excluded.saints,
  is_active = true,
  updated_at = now();

with source as (
  select *
  from jsonb_to_recordset($questions$
[
  {"category":"married","title":"Fidelity","commandment":6,"type":"mortal","question":"Have I engaged in emotional infidelity or an inappropriate attachment to someone other than my spouse?","description":"Emotional affairs violate the exclusivity of marital love and can lead to adultery (CCC 2380–2381).","counsels":["Cut off all inappropriate contact immediately.","Be transparent with your spouse.","Seek marriage counseling or spiritual direction."],"prevention":["Set clear boundaries with members of the opposite sex","Share your struggles with your spouse regularly","Avoid private messaging with former romantic interests"],"saints":["St. Joseph","St. Monica"]},
  {"category":"married","title":"Openness to Life","commandment":6,"type":"mortal","question":"Have I used artificial contraception to prevent pregnancy?","description":"Contraception separates the unitive and procreative meanings of the marital act and is gravely disordered (CCC 2370).","counsels":["Learn and practice Natural Family Planning (NFP).","Discuss openness to life with your spouse.","Confess and seek guidance from a faithful priest."],"prevention":["Take an NFP course together","Read Humanae Vitae","Pray together about family planning"],"saints":["Sts. Louis and Zélie Martin"]},
  {"category":"married","title":"Charity","commandment":4,"type":"grave","question":"Have I neglected my spouse emotionally, spiritually, or physically?","description":"Spouses are called to mutual self-giving; neglect undermines the marriage covenant (CCC 1643).","counsels":["Schedule regular time together without distractions.","Ask your spouse how they feel loved.","Prioritize your marriage over work and hobbies."],"prevention":["Weekly date night","Daily check-in conversations","Annual marriage retreat"],"saints":["Sts. Louis and Zélie Martin"]},
  {"category":"married","title":"Leadership","commandment":4,"type":"grave","question":"Have I failed to lead my family in faith, prayer, or moral formation?","description":"Parents are the primary educators of their children and must guide them toward God (CCC 2223–2226).","counsels":["Start family prayer, even if briefly.","Teach your children about the faith by example.","Take initiative rather than waiting for your spouse."],"prevention":["Family Rosary or bedtime prayers","Sunday Mass as a non-negotiable family habit","Read a Bible story together at meals"],"saints":["St. Joseph","St. John Chrysostom"]},
  {"category":"married","title":"Charity","commandment":5,"type":"mortal","question":"Have I verbally or emotionally abused my spouse or children?","description":"Verbal and emotional abuse violates the dignity of the person and destroys trust in the family (CCC 2302–2303).","counsels":["Apologize sincerely and commit to change.","Seek professional counseling or anger management.","Ask your family for forgiveness."],"prevention":["Walk away when anger escalates","Practice speaking with gentleness","Regular Confession and self-examination"],"saints":["St. Francis de Sales"]},
  {"category":"married","title":"Prayer Life","commandment":1,"type":"grave","question":"Have I failed to pray with or for my spouse and family?","description":"The domestic church is strengthened by shared prayer; neglecting it weakens the family's spiritual life (CCC 2685).","counsels":["Begin with one shared prayer a day (grace before meals, bedtime).","Invite your spouse to pray together, even briefly.","Pray for your spouse's intentions daily."],"prevention":["Set a specific time for family prayer","Pray the Rosary together weekly","Attend Mass together as a family"],"saints":["Sts. Louis and Zélie Martin"]},
  {"category":"married","title":"Justice","commandment":7,"type":"grave","question":"Have I been financially irresponsible, putting my family at risk through reckless spending, gambling, or debt?","description":"Spouses have a duty of justice to provide for their family's material needs responsibly (CCC 2409).","counsels":["Create a family budget together.","Confess any hidden debts or spending to your spouse.","Seek financial counseling if needed."],"prevention":["Monthly budget review with your spouse","Avoid impulsive purchases","Practice generosity within your means"],"saints":["St. Joseph"]},
  {"category":"married","title":"Mercy","commandment":5,"type":"grave","question":"Have I refused to forgive my spouse or held grudges in our marriage?","description":"Forgiveness is essential to married love; refusing it hardens the heart and damages the bond (CCC 2843).","counsels":["Choose forgiveness as an act of the will, even when feelings resist.","Bring unresolved hurts to Confession and prayer.","Seek couples counseling for deep wounds."],"prevention":["Never go to bed angry — resolve conflicts daily","Pray the Our Father together, reflecting on 'forgive us as we forgive'","Practice small acts of kindness after disagreements"],"saints":["St. Rita of Cascia"]},
  {"category":"married","title":"Chastity","commandment":6,"type":"mortal","question":"Have I refused the marital debt or used my spouse for selfish sexual gratification?","description":"Spouses owe mutual self-giving; selfishness or coercion in the marital act violates its meaning (CCC 2362–2363).","counsels":["Discuss intimacy honestly and charitably with your spouse.","Put your spouse's needs before your own.","Seek guidance from a faithful priest if needed."],"prevention":["Read Theology of the Body together","Communicate openly about expectations","Pray for purity within marriage"],"saints":["St. John Paul II"]},
  {"category":"married","title":"Openness to Life","commandment":5,"type":"mortal","question":"Have I pressured my spouse toward sterilization or abortion?","description":"Direct sterilization and abortion are gravely sinful; they reject God's gift of life (CCC 2271, 2399).","counsels":["Repent and confess immediately.","If sterilization occurred, seek pastoral guidance on reversal or acceptance.","Support your spouse through healing."],"prevention":["Learn Church teaching on life issues together","Trust in God's providence","Join a pro-life support group"],"saints":["St. Gianna Beretta Molla"]},
  {"category":"married","title":"Temperance","commandment":5,"type":"grave","question":"Have I prioritized work, hobbies, or screens over quality time with my family?","description":"Neglecting family for distractions fails in the duty of love owed to spouse and children (CCC 2211).","counsels":["Set firm boundaries around work hours.","Put devices away during family time.","Be fully present to your spouse and children."],"prevention":["Daily device-free family meals","Weekly family activity or outing","Limit social media to set times"],"saints":["St. Joseph"]},
  {"category":"married","title":"Truth","commandment":8,"type":"mortal","question":"Have I lied to my spouse about serious matters or lived a double life?","description":"Lying destroys trust, the foundation of marriage; serious deception is gravely sinful (CCC 2482–2484).","counsels":["Confess the truth to your spouse with humility.","Accept the consequences of your dishonesty.","Rebuild trust through consistent transparency."],"prevention":["Practice radical honesty, even about small things","Share passwords and financial information openly","Seek accountability from a trusted friend or mentor"],"saints":["St. Thomas More"]},
  {"category":"married","title":"Charity","commandment":4,"type":"grave","question":"Have I spoken badly about my spouse to others or publicly humiliated them?","description":"Detraction against one's spouse wounds their reputation and violates marital charity (CCC 2477).","counsels":["Apologize to your spouse and to those you spoke to.","Speak positively about your spouse in public.","Bring complaints to your spouse directly, not to others."],"prevention":["Follow the rule: praise in public, correct in private","Vent only to a spiritual director or counselor","Pray for your spouse when frustrated"],"saints":["St. Francis de Sales"]},
  {"category":"married","title":"Faith","commandment":1,"type":"grave","question":"Have I failed to raise my children in the Catholic faith or neglected their sacramental preparation?","description":"Parents promise at Baptism to raise children in the faith; neglecting this duty is a serious failure (CCC 2225–2226).","counsels":["Enroll children in religious education.","Teach them basic prayers and the meaning of the sacraments.","Be an example of faith they can follow."],"prevention":["Attend Mass together every Sunday","Pray with your children daily","Discuss faith naturally in everyday life"],"saints":["Sts. Louis and Zélie Martin","St. Monica"]},
  {"category":"married","title":"Patience","commandment":5,"type":"grave","question":"Have I been impatient, harsh, or dismissive toward my children?","description":"Parents must guide children with patience and love, not provoke them to anger (CCC 2223; Eph 6:4).","counsels":["Apologize to your children when you lose your temper.","Discipline with calm and reason, not rage.","Spend one-on-one time with each child."],"prevention":["Pause before reacting in frustration","Establish consistent, fair discipline routines","Pray for patience daily"],"saints":["St. John Bosco"]},
  {"category":"married","title":"Humility","commandment":4,"type":"grave","question":"Have I refused to seek help for my marriage when it was struggling?","description":"Pride can prevent spouses from seeking the help they need, allowing wounds to deepen (CCC 1608).","counsels":["Reach out to a priest, deacon, or Catholic marriage counselor.","Attend a marriage enrichment program or retreat.","Be honest about the state of your marriage."],"prevention":["Annual marriage retreat or enrichment weekend","Maintain friendships with other faithful married couples","Regular Confession and spiritual direction"],"saints":["St. Rita of Cascia"]},
  {"category":"married","title":"Chastity","commandment":6,"type":"mortal","question":"Have I viewed pornography or engaged in lustful fantasies about someone other than my spouse?","description":"Pornography and lustful fantasies violate marital fidelity and the dignity of the human person (CCC 2354, 2528).","counsels":["Confess immediately and install content filters.","Tell your spouse if appropriate and seek accountability.","Join a recovery group or program."],"prevention":["Install accountability software on all devices","Avoid being alone with screens late at night","Pray the Rosary daily for purity"],"saints":["St. Augustine","St. Joseph"]}
]
$questions$::jsonb) as entry(
  category text,
  title text,
  commandment smallint,
  type text,
  question text,
  description text,
  counsels jsonb,
  prevention jsonb,
  saints jsonb
)
)
insert into app.examination_of_conscience_questions (
  category, title, commandment, severity, question, description,
  counsels, prevention, saints, is_active
)
select category, title, commandment, type, question, description,
  array(select jsonb_array_elements_text(counsels)),
  array(select jsonb_array_elements_text(prevention)),
  array(select jsonb_array_elements_text(saints)), true
from source
on conflict (question) do update set
  category = excluded.category,
  title = excluded.title,
  commandment = excluded.commandment,
  severity = excluded.severity,
  description = excluded.description,
  counsels = excluded.counsels,
  prevention = excluded.prevention,
  saints = excluded.saints,
  is_active = true,
  updated_at = now();

select platform.apply_spanish_catalog_translations();

do $$
declare
  table_name text;
  row_count bigint;
begin
  foreach table_name in array array[
    'activity_definitions',
    'level_definitions',
    'badge_definitions',
    'badge_requirement_definitions',
    'badge_requirement_activity_rules',
    'game_balance_config',
    'virtue_definitions',
    'saint_definitions',
    'demon_definitions',
    'demon_virtue_affinities',
    'demon_attacks',
    'demon_defenses',
    'demon_defeat_rewards',
    'demon_defense_activity_rules',
    'point_rules',
    'challenge_definitions'
  ]
  loop
    execute format('select count(*) from competition.%I', table_name)
      into row_count;
    if row_count = 0 then
      raise exception 'PRODUCTION_CATALOG_TABLE_EMPTY: competition.%', table_name;
    end if;
  end loop;
end
$$;

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
  ) catalog_checks;

  if missing_translations <> 0 then
    raise exception 'PRODUCTION_CATALOG_TRANSLATIONS_MISSING: %', missing_translations;
  end if;
end
$$;
