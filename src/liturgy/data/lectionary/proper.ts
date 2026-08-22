import type {
  LectionaryEntry,
  ReadingSet,
  ScriptureReading,
  SundayCycle,
} from '@/liturgy/models';

const reading = (
  type: ScriptureReading['type'],
  citation: string,
  optional = false,
) => (optional ? { type, citation, optional } : { type, citation });

const set = (
  id: string,
  label: ReadingSet['label'],
  readings: ScriptureReading[],
): ReadingSet => ({ id, label, readings, selectionRule: 'REQUIRED_PROPER' });

const proper = (...readingSets: ReadingSet[]): LectionaryEntry => ({
  selectionRule: 'REQUIRED_PROPER',
  readingSets,
});

const optionalProper = (...readingSets: ReadingSet[]): LectionaryEntry => ({
  selectionRule: 'OPTIONAL_PROPER',
  readingSets: readingSets.map((readingSet) => ({
    ...readingSet,
    selectionRule: 'OPTIONAL_PROPER',
  })),
});

export const properReadings: Record<string, LectionaryEntry> = {
  'mary-mother-of-god': proper(
    set('mary-mother-of-god-default', 'DEFAULT', [
      reading('FIRST_READING', 'Nm 6:22-27'),
      reading('RESPONSORIAL_PSALM', 'Ps 67:2-3, 5, 6, 8'),
      reading('SECOND_READING', 'Gal 4:4-7'),
      reading('GOSPEL', 'Lk 2:16-21'),
    ]),
  ),
  'saint-joseph': proper(
    set('saint-joseph-matthew', 'DEFAULT', [
      reading('FIRST_READING', '2 Sm 7:4-5a, 12-14a, 16'),
      reading('RESPONSORIAL_PSALM', 'Ps 89:2-3, 4-5, 27, 29'),
      reading('SECOND_READING', 'Rom 4:13, 16-18, 22'),
      reading('GOSPEL', 'Mt 1:16, 18-21, 24a'),
    ]),
    set('saint-joseph-luke', 'DEFAULT', [
      reading('FIRST_READING', '2 Sm 7:4-5a, 12-14a, 16'),
      reading('RESPONSORIAL_PSALM', 'Ps 89:2-3, 4-5, 27, 29'),
      reading('SECOND_READING', 'Rom 4:13, 16-18, 22'),
      reading('GOSPEL', 'Lk 2:41-51a'),
    ]),
  ),
  annunciation: proper(
    set('annunciation-default', 'DEFAULT', [
      reading('FIRST_READING', 'Is 7:10-14; 8:10'),
      reading('RESPONSORIAL_PSALM', 'Ps 40:7-8a, 8b-9, 10, 11'),
      reading('SECOND_READING', 'Heb 10:4-10'),
      reading('GOSPEL', 'Lk 1:26-38'),
    ]),
  ),
  'nativity-of-saint-john-the-baptist': proper(
    set('nativity-of-saint-john-the-baptist-default', 'DEFAULT', [
      reading('FIRST_READING', 'Is 49:1-6'),
      reading('RESPONSORIAL_PSALM', 'Ps 139:1b-3, 13-14ab, 14c-15'),
      reading('SECOND_READING', 'Acts 13:22-26'),
      reading('GOSPEL', 'Lk 1:57-66, 80'),
    ]),
  ),
  'saints-peter-and-paul': proper(
    set('saints-peter-and-paul-default', 'DEFAULT', [
      reading('FIRST_READING', 'Acts 12:1-11'),
      reading('RESPONSORIAL_PSALM', 'Ps 34:2-3, 4-5, 6-7, 8-9'),
      reading('SECOND_READING', '2 Tm 4:6-8, 17-18'),
      reading('GOSPEL', 'Mt 16:13-19'),
    ]),
  ),
  transfiguration: proper(
    set('transfiguration-default', 'DEFAULT', [
      reading('FIRST_READING', 'Dn 7:9-10, 13-14'),
      reading('RESPONSORIAL_PSALM', 'Ps 97:1-2, 5-6, 9'),
      reading('SECOND_READING', '2 Pt 1:16-19'),
      reading('GOSPEL', 'Mt 17:1-9'),
    ]),
  ),
  assumption: proper(
    set('assumption-default', 'DEFAULT', [
      reading('FIRST_READING', 'Rv 11:19a; 12:1-6a, 10ab'),
      reading('RESPONSORIAL_PSALM', 'Ps 45:10, 11, 12, 16'),
      reading('SECOND_READING', '1 Cor 15:20-27'),
      reading('GOSPEL', 'Lk 1:39-56'),
    ]),
  ),
  'all-saints': proper(
    set('all-saints-default', 'DEFAULT', [
      reading('FIRST_READING', 'Rv 7:2-4, 9-14'),
      reading('RESPONSORIAL_PSALM', 'Ps 24:1bc-2, 3-4ab, 5-6'),
      reading('SECOND_READING', '1 Jn 3:1-3'),
      reading('GOSPEL', 'Mt 5:1-12a'),
    ]),
  ),
  'immaculate-conception': proper(
    set('immaculate-conception-default', 'DEFAULT', [
      reading('FIRST_READING', 'Gn 3:9-15, 20'),
      reading('RESPONSORIAL_PSALM', 'Ps 98:1, 2-3ab, 3cd-4'),
      reading('SECOND_READING', 'Eph 1:3-6, 11-12'),
      reading('GOSPEL', 'Lk 1:26-38'),
    ]),
  ),
  'saint-augustine': optionalProper(
    set('saint-augustine-proper-option', 'DEFAULT', [
      reading('FIRST_READING', 'Sir 15:1-6'),
      reading('RESPONSORIAL_PSALM', 'Ps 119:9, 10, 11, 12, 13, 14'),
      reading('GOSPEL', 'Mt 23:8-12'),
    ]),
  ),
  'saint-therese-of-lisieux': optionalProper(
    set('saint-therese-proper-option', 'DEFAULT', [
      reading('FIRST_READING', 'Is 66:10-14c'),
      reading('RESPONSORIAL_PSALM', 'Ps 131:1bcde, 2, 3'),
      reading('GOSPEL', 'Mt 18:1-5'),
    ]),
  ),
  christmas: proper(
    set('christmas-vigil', 'VIGIL', [
      reading('FIRST_READING', 'Is 62:1-5'),
      reading('RESPONSORIAL_PSALM', 'Ps 89:4-5, 16-17, 27, 29'),
      reading('SECOND_READING', 'Acts 13:16-17, 22-25'),
      reading('GOSPEL', 'Mt 1:1-25'),
    ]),
    set('christmas-night', 'NIGHT', [
      reading('FIRST_READING', 'Is 9:1-6'),
      reading('RESPONSORIAL_PSALM', 'Ps 96:1-2, 2-3, 11-12, 13'),
      reading('SECOND_READING', 'Ti 2:11-14'),
      reading('GOSPEL', 'Lk 2:1-14'),
    ]),
    set('christmas-dawn', 'DAWN', [
      reading('FIRST_READING', 'Is 62:11-12'),
      reading('RESPONSORIAL_PSALM', 'Ps 97:1, 6, 11-12'),
      reading('SECOND_READING', 'Ti 3:4-7'),
      reading('GOSPEL', 'Lk 2:15-20'),
    ]),
    set('christmas-day', 'DAY', [
      reading('FIRST_READING', 'Is 52:7-10'),
      reading('RESPONSORIAL_PSALM', 'Ps 98:1, 2-3, 3-4, 5-6'),
      reading('SECOND_READING', 'Heb 1:1-6'),
      reading('GOSPEL', 'Jn 1:1-18'),
    ]),
  ),
  epiphany: proper(
    set('epiphany-default', 'DEFAULT', [
      reading('FIRST_READING', 'Is 60:1-6'),
      reading('RESPONSORIAL_PSALM', 'Ps 72:1-2, 7-8, 10-11, 12-13'),
      reading('SECOND_READING', 'Eph 3:2-3a, 5-6'),
      reading('GOSPEL', 'Mt 2:1-12'),
    ]),
  ),
  'ash-wednesday': proper(
    set('ash-wednesday-default', 'DEFAULT', [
      reading('FIRST_READING', 'Jl 2:12-18'),
      reading('RESPONSORIAL_PSALM', 'Ps 51:3-4, 5-6ab, 12-13, 14 and 17'),
      reading('SECOND_READING', '2 Cor 5:20—6:2'),
      reading('GOSPEL_ACCLAMATION', 'Ps 95:8'),
      reading('GOSPEL', 'Mt 6:1-6, 16-18'),
    ]),
  ),
  'holy-thursday': proper(
    set('holy-thursday-default', 'DEFAULT', [
      reading('FIRST_READING', 'Ex 12:1-8, 11-14'),
      reading('RESPONSORIAL_PSALM', 'Ps 116:12-13, 15-16bc, 17-18'),
      reading('SECOND_READING', '1 Cor 11:23-26'),
      reading('GOSPEL_ACCLAMATION', 'Jn 13:34'),
      reading('GOSPEL', 'Jn 13:1-15'),
    ]),
  ),
  'good-friday': proper(
    set('good-friday-default', 'DEFAULT', [
      reading('FIRST_READING', 'Is 52:13—53:12'),
      reading('RESPONSORIAL_PSALM', 'Ps 31:2, 6, 12-13, 15-16, 17, 25'),
      reading('SECOND_READING', 'Heb 4:14-16; 5:7-9'),
      reading('GOSPEL', 'Jn 18:1—19:42'),
    ]),
  ),
  'easter-vigil': proper(
    set('easter-vigil-default', 'VIGIL', [
      reading('FIRST_READING', 'Gn 1:1—2:2', true),
      reading(
        'RESPONSORIAL_PSALM',
        'Ps 104:1-2, 5-6, 10, 12, 13-14, 24, 35',
        true,
      ),
      reading('FIRST_READING', 'Gn 22:1-18', true),
      reading('RESPONSORIAL_PSALM', 'Ps 16:5, 8, 9-10, 11', true),
      reading('FIRST_READING', 'Ex 14:15—15:1'),
      reading('RESPONSORIAL_PSALM', 'Ex 15:1-2, 3-4, 5-6, 17-18'),
      reading('FIRST_READING', 'Is 54:5-14', true),
      reading('RESPONSORIAL_PSALM', 'Ps 30:2, 4, 5-6, 11-12a, 13b', true),
      reading('FIRST_READING', 'Is 55:1-11', true),
      reading('RESPONSORIAL_PSALM', 'Is 12:2-3, 4bcd, 5-6', true),
      reading('FIRST_READING', 'Bar 3:9-15, 32—4:4', true),
      reading('RESPONSORIAL_PSALM', 'Ps 19:8, 9, 10, 11', true),
      reading('FIRST_READING', 'Ez 36:16-17a, 18-28', true),
      reading('RESPONSORIAL_PSALM', 'Ps 42:3, 5; 43:3, 4', true),
      reading('EPISTLE', 'Rom 6:3-11'),
      reading('RESPONSORIAL_PSALM', 'Ps 118:1-2, 16-17, 22-23'),
      reading('GOSPEL', 'Mt 28:1-10'),
    ]),
  ),
  'easter-sunday': proper(
    set('easter-sunday-day', 'DAY', [
      reading('FIRST_READING', 'Acts 10:34a, 37-43'),
      reading('RESPONSORIAL_PSALM', 'Ps 118:1-2, 16-17, 22-23'),
      reading('SECOND_READING', 'Col 3:1-4'),
      reading('GOSPEL', 'Jn 20:1-9'),
    ]),
  ),
  ascension: proper(
    set('ascension-day', 'DAY', [
      reading('FIRST_READING', 'Acts 1:1-11'),
      reading('RESPONSORIAL_PSALM', 'Ps 47:2-3, 6-7, 8-9'),
      reading('SECOND_READING', 'Eph 1:17-23'),
      reading('GOSPEL', 'Mt 28:16-20'),
    ]),
  ),
  pentecost: proper(
    set('pentecost-vigil', 'VIGIL', [
      reading('FIRST_READING', 'Jl 3:1-5'),
      reading('RESPONSORIAL_PSALM', 'Ps 104:1-2, 24, 35, 27-28, 29, 30'),
      reading('SECOND_READING', 'Rom 8:22-27'),
      reading('GOSPEL', 'Jn 7:37-39'),
    ]),
    set('pentecost-day', 'DAY', [
      reading('FIRST_READING', 'Acts 2:1-11'),
      reading('RESPONSORIAL_PSALM', 'Ps 104:1, 24, 29-30, 31, 34'),
      reading('SECOND_READING', '1 Cor 12:3b-7, 12-13'),
      reading('GOSPEL', 'Jn 20:19-23'),
    ]),
  ),
  'corpus-christi': proper(
    set('corpus-christi-day', 'DAY', [
      reading('FIRST_READING', 'Gn 14:18-20'),
      reading('RESPONSORIAL_PSALM', 'Ps 110:1, 2, 3, 4'),
      reading('SECOND_READING', '1 Cor 11:23-26'),
      reading('GOSPEL', 'Lk 9:11b-17'),
    ]),
  ),
  'sacred-heart': proper(
    set('sacred-heart-day', 'DAY', [
      reading('FIRST_READING', 'Dt 7:6-11'),
      reading('RESPONSORIAL_PSALM', 'Ps 103:1-2, 3-4, 6-7, 8, 10'),
      reading('SECOND_READING', '1 Jn 4:7-16'),
      reading('GOSPEL', 'Mt 11:25-30'),
    ]),
  ),
  'palm-sunday': proper(
    set('palm-sunday-a', 'DEFAULT', [
      reading('FIRST_READING', 'Is 50:4-7'),
      reading('RESPONSORIAL_PSALM', 'Ps 22:8-9, 17-18, 19-20, 23-24'),
      reading('SECOND_READING', 'Phil 2:6-11'),
      reading('GOSPEL', 'Mt 26:14—27:66'),
    ]),
  ),
};

/** Proper sets whose Gospel changes with the Sunday Year A/B/C cycle. */
export const cycleSpecificProperReadings: Partial<
  Record<string, Partial<Record<SundayCycle, LectionaryEntry>>>
> = {
  'palm-sunday': {
    A: properReadings['palm-sunday'],
    B: proper(
      set('palm-sunday-b', 'DEFAULT', [
        reading('FIRST_READING', 'Is 50:4-7'),
        reading('RESPONSORIAL_PSALM', 'Ps 22:8-9, 17-18, 19-20, 23-24'),
        reading('SECOND_READING', 'Phil 2:6-11'),
        reading('GOSPEL', 'Mk 14:1—15:47'),
      ]),
    ),
    C: proper(
      set('palm-sunday-c', 'DEFAULT', [
        reading('FIRST_READING', 'Is 50:4-7'),
        reading('RESPONSORIAL_PSALM', 'Ps 22:8-9, 17-18, 19-20, 23-24'),
        reading('SECOND_READING', 'Phil 2:6-11'),
        reading('GOSPEL', 'Lk 22:14—23:56'),
      ]),
    ),
  },
  ascension: {
    A: properReadings.ascension,
    B: proper(
      set('ascension-day-b', 'DAY', [
        reading('FIRST_READING', 'Acts 1:1-11'),
        reading('RESPONSORIAL_PSALM', 'Ps 47:2-3, 6-7, 8-9'),
        reading('SECOND_READING', 'Eph 1:17-23'),
        reading('GOSPEL', 'Mk 16:15-20'),
      ]),
    ),
    C: proper(
      set('ascension-day-c', 'DAY', [
        reading('FIRST_READING', 'Acts 1:1-11'),
        reading('RESPONSORIAL_PSALM', 'Ps 47:2-3, 6-7, 8-9'),
        reading('SECOND_READING', 'Eph 1:17-23'),
        reading('GOSPEL', 'Lk 24:46-53'),
      ]),
    ),
  },
};
