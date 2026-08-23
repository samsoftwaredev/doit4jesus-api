-- Keep the production catalogue aligned with the seeded saint definitions.
-- Existing rows retain their stable IDs because profiles and game data may
-- reference them through saint_avatar_id or saint_mentor_id.
insert into competition.saint_definitions (id, code, name, description, is_active)
values
  ('a1000000-0000-4000-8000-000000000001', 'IGNATIUS_OF_LOYOLA', 'St. Ignatius of Loyola', 'A mentor of discernment and ordered attention.', true),
  ('a1000000-0000-4000-8000-000000000002', 'JOSEPH', 'St. Joseph', 'A mentor of steady work, responsibility, and quiet service.', true),
  ('a1000000-0000-4000-8000-000000000004', 'THERESE_OF_LISIEUX', 'St. Thérèse of Lisieux', 'A mentor of hidden love and the little way.', true),
  ('a1000000-0000-4000-8000-000000000005', 'BENEDICT', 'St. Benedict of Nursia', 'A mentor of prayerful work, stability, and holy order.', true),
  ('a1000000-0000-4000-8000-000000000006', 'FRANCIS_OF_ASSISI', 'St. Francis of Assisi', 'A mentor of gratitude, simplicity, and joy in the good of others.', true),
  ('a1000000-0000-4000-8000-000000000007', 'JOAN_OF_ARC', 'St. Joan of Arc', 'A mentor of courageous obedience despite fear.', true),
  ('a1000000-0000-4000-8000-000000000008', 'PETER', 'St. Peter', 'A mentor of repentance and returning after failure.', true),
  ('a1000000-0000-4000-8000-000000000010', 'LAWRENCE', 'St. Lawrence', 'A mentor of generosity and love of people over possessions.', true),
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
