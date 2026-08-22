import type {
  LectionaryEntry,
  ReadingSet,
  ScriptureReading,
} from '@/liturgy/models';

const reading = (type: ScriptureReading['type'], citation: string) => ({
  type,
  citation,
});

const weekdaySet = (
  id: string,
  readings: ScriptureReading[],
): LectionaryEntry => ({
  selectionRule: 'WEEKDAY',
  readingSets: [{ id, label: 'DEFAULT', readings, selectionRule: 'WEEKDAY' }],
});

/**
 * The key is built from the resolved calendar context, never from a civil date.
 * Additional temporal weeks can be added without changing the resolver.
 */
export const temporalReadings: Record<string, LectionaryEntry> = {
  'ADVENT:1:0:A': weekdaySet('advent-week-1-sunday-a', [
    reading('FIRST_READING', 'Is 2:1-5'),
    reading('RESPONSORIAL_PSALM', 'Ps 122:1-2, 3-4, 4-5, 6-7, 8-9'),
    reading('SECOND_READING', 'Rom 13:11-14'),
    reading('GOSPEL', 'Mt 24:37-44'),
  ]),
  'ADVENT:1:0:B': weekdaySet('advent-week-1-sunday-b', [
    reading('FIRST_READING', 'Is 63:16b-17, 19b; 64:2-7'),
    reading('RESPONSORIAL_PSALM', 'Ps 80:2-3, 15-16, 18-19'),
    reading('SECOND_READING', '1 Cor 1:3-9'),
    reading('GOSPEL', 'Mk 13:33-37'),
  ]),
  'ADVENT:1:0:C': weekdaySet('advent-week-1-sunday-c', [
    reading('FIRST_READING', 'Jer 33:14-16'),
    reading('RESPONSORIAL_PSALM', 'Ps 25:4-5, 8-9, 10, 14'),
    reading('SECOND_READING', '1 Thes 3:12—4:2'),
    reading('GOSPEL', 'Lk 21:25-28, 34-36'),
  ]),
  'ADVENT:2:1:II': weekdaySet('advent-week-2-monday', [
    reading('FIRST_READING', 'Is 35:1-10'),
    reading('RESPONSORIAL_PSALM', 'Ps 85:9ab and 10, 11-12, 13-14'),
    reading('GOSPEL', 'Lk 5:17-26'),
  ]),
  'LENT:2:1:II': weekdaySet('lent-week-2-monday', [
    reading('FIRST_READING', 'Dn 9:4b-10'),
    reading('RESPONSORIAL_PSALM', 'Ps 79:8, 9, 11 and 13'),
    reading('GOSPEL', 'Lk 6:36-38'),
  ]),
  'EASTER:2:4:II': weekdaySet('easter-week-2-thursday', [
    reading('FIRST_READING', 'Acts 5:27-33'),
    reading('RESPONSORIAL_PSALM', 'Ps 34:2 and 9, 17-18, 19-20'),
    reading('GOSPEL', 'Jn 3:31-36'),
  ]),
  'ORDINARY_TIME:20:5:I': weekdaySet('ordinary-time-week-20-friday-i', [
    reading('FIRST_READING', 'Jgs 11:29-39a'),
    reading('RESPONSORIAL_PSALM', 'Ps 40:5, 7-8a, 8b-9, 10'),
    reading('GOSPEL', 'Mt 19:16-22'),
  ]),
  'ORDINARY_TIME:20:5:II': weekdaySet('ordinary-time-week-20-friday-ii', [
    reading('FIRST_READING', 'Ez 37:1-14'),
    reading('RESPONSORIAL_PSALM', 'Ps 107:2-3, 4-5, 6-7, 8-9'),
    reading('GOSPEL_ACCLAMATION', 'Ps 25:4b, 5a'),
    reading('GOSPEL', 'Mt 22:34-40'),
  ]),
  'ORDINARY_TIME:21:5:II': weekdaySet('ordinary-time-week-21-friday-ii', [
    reading('FIRST_READING', '1 Cor 1:17-25'),
    reading('RESPONSORIAL_PSALM', 'Ps 33:1-2, 4-5, 10-11'),
    reading('GOSPEL', 'Mt 25:1-13'),
  ]),
};
