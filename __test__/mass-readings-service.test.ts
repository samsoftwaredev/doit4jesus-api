import {
  MassReadingsService,
  applicationToday,
  getMassReadings,
} from '../src/liturgy/MassReadingsService';
import { LiturgicalDayResolver } from '../src/liturgy/calendar/LiturgicalDayResolver';
import { usccbDailyLectionary } from '../src/liturgy/data/lectionary/usccb';
import { LocalLectionaryRepository } from '../src/liturgy/lectionary/LectionaryRepository';
import { LectionaryResolver } from '../src/liturgy/lectionary/LectionaryResolver';
import { NabreScriptureRepository } from '../src/liturgy/scripture/NabreScriptureRepository';
import { NabreVerseMapper } from '../src/liturgy/scripture/NabreVerseMapper';

const calendar = new LiturgicalDayResolver();
const lectionary = new LectionaryResolver(new LocalLectionaryRepository());

describe('LiturgicalDayResolver', () => {
  it.each([
    ['2025-11-30', 'A'],
    ['2026-11-29', 'B'],
    ['2027-11-28', 'C'],
  ] as const)(
    'uses Sunday cycle %s at the first Sunday of Advent',
    (date, cycle) => {
      expect(calendar.resolve(date).sundayCycle).toBe(cycle);
    },
  );

  it.each([
    ['2026-01-04', { country: 'US' }, 'epiphany'],
    ['2026-02-18', {}, 'ash-wednesday'],
    ['2026-04-02', {}, 'holy-thursday'],
    ['2026-04-03', {}, 'good-friday'],
    ['2026-04-05', {}, 'easter-sunday'],
    ['2026-05-17', { country: 'US' }, 'ascension'],
    ['2026-05-24', {}, 'pentecost'],
    ['2026-06-07', { country: 'US' }, 'corpus-christi'],
    ['2026-06-12', {}, 'sacred-heart'],
  ] as const)(
    'resolves required proper readings for %s',
    (date, options, celebrationId) => {
      const day = calendar.resolve(date, options);
      const result = lectionary.resolve(day);

      expect(day.primaryCelebration.id).toBe(celebrationId);
      expect(result.primary?.readings.length).toBeGreaterThan(0);
    },
  );

  it.each([
    ['2026-12-07', 'ADVENT', 2, 1],
    ['2026-03-02', 'LENT', 2, 1],
    ['2026-04-16', 'EASTER', 2, 4],
  ] as const)('uses a temporal entry for %s', (date, season, week, weekday) => {
    const day = calendar.resolve(date);
    const result = lectionary.resolve(day);

    expect(day).toMatchObject({ season, week, weekday });
    expect(result.primary?.selectionRule).toBe('WEEKDAY');
  });

  it('uses a Sunday-transferred Ascension in the United States', () => {
    expect(
      calendar.resolve('2026-05-17', { country: 'US' }).primaryCelebration.id,
    ).toBe('ascension');
    expect(calendar.resolve('2026-05-14').primaryCelebration.id).toBe(
      'ascension',
    );
  });
});

describe('LectionaryResolver', () => {
  it('uses the Year II ordinary weekday first reading and the shared Gospel sequence', () => {
    const day = calendar.resolve('2026-08-21');
    const result = lectionary.resolve(day);

    expect(day).toMatchObject({
      season: 'ORDINARY_TIME',
      week: 20,
      weekdayCycle: 'II',
      psalterWeek: 4,
      primaryCelebration: {
        id: 'saint-pius-x',
        readingSelectionRule: 'WEEKDAY',
      },
    });
    expect(result.primary?.readings).toEqual(
      expect.arrayContaining([
        { type: 'FIRST_READING', citation: 'Ez 37:1-14' },
        { type: 'GOSPEL', citation: 'Mt 22:34-40' },
      ]),
    );
  });

  it('uses the Cycle I first reading on the same ordinary weekday context', () => {
    const result = lectionary.resolve(calendar.resolve('2025-08-22'));
    expect(result.primary?.readings).toEqual(
      expect.arrayContaining([
        { type: 'FIRST_READING', citation: 'Jgs 11:29-39a' },
      ]),
    );
  });

  it('keeps a memorial’s weekday readings and exposes its optional proper set', () => {
    const result = lectionary.resolve(calendar.resolve('2026-08-28'));

    expect(result.readingSets).toHaveLength(2);
    expect(result.readingSets[0]).toMatchObject({
      selectionRule: 'WEEKDAY',
      readings: expect.arrayContaining([
        { type: 'FIRST_READING', citation: '1 Cor 1:17-25' },
      ]),
    });
    expect(result.readingSets[1]).toMatchObject({
      selectionRule: 'OPTIONAL_PROPER',
    });
  });

  it('returns all Christmas Mass variants instead of flattening them', () => {
    const result = lectionary.resolve(
      calendar.resolve('2026-12-25', { country: 'US' }),
    );

    expect(result.readingSets.map((readingSet) => readingSet.label)).toEqual([
      'VIGIL',
      'NIGHT',
      'DAWN',
      'DAY',
    ]);
    expect(result.readingSets[3].readings).toEqual(
      expect.arrayContaining([{ type: 'GOSPEL', citation: 'Jn 1:1-18' }]),
    );
  });

  it('supports the Easter Vigil’s variable reading sequence', () => {
    const result = lectionary.resolve(calendar.resolve('2026-04-04'));
    expect(result.primary?.label).toBe('VIGIL');
    expect(result.primary?.readings.length).toBeGreaterThan(8);
    expect(result.primary?.readings.at(-1)).toEqual({
      type: 'GOSPEL',
      citation: 'Mt 28:1-10',
    });
  });

  it.each([
    ['2026-03-29', 'A', 'Mt 26:14—27:66'],
    ['2027-03-21', 'B', 'Mk 14:1—15:47'],
    ['2028-04-09', 'C', 'Lk 22:14—23:56'],
  ] as const)(
    'uses the Year %s Palm Sunday Passion Gospel',
    (date, cycle, gospel) => {
      const day = calendar.resolve(date);
      const result = lectionary.resolve(day);

      expect(day.sundayCycle).toBe(cycle);
      expect(result.primary?.readings).toEqual(
        expect.arrayContaining([{ type: 'GOSPEL', citation: gospel }]),
      );
    },
  );
});

describe('MassReadingsService', () => {
  it('has a local USCCB record for every day in the 2026 civil year', () => {
    const start = new Date('2026-01-01T00:00:00.000Z');
    for (let offset = 0; offset < 365; offset += 1) {
      const date = new Date(start);
      date.setUTCDate(date.getUTCDate() + offset);
      expect(usccbDailyLectionary.has(date.toISOString().slice(0, 10))).toBe(
        true,
      );
    }
  });

  it('resolves every 2026 USCCB reading and maps available local NABRE text', async () => {
    for (const date of usccbDailyLectionary.keys()) {
      const result = await getMassReadings({ date, country: 'US' });
      expect(result.readings).not.toHaveLength(0);
      for (const reading of result.readings) {
        expect(reading.citation).toEqual(expect.any(String));
        if (reading.text !== undefined)
          expect(reading.text).not.toHaveLength(0);
      }
    }
  });

  it('returns a daily payload with local Scripture text and regional metadata', async () => {
    const result = await getMassReadings({
      date: '2026-08-21',
      country: 'us',
      diocese: 'Dallas',
      locale: 'en-US',
    });

    expect(result).toMatchObject({
      date: '2026-08-21',
      celebration: {
        id: 'saint-pius-x-pope',
        season: 'ORDINARY_TIME',
        color: ['WHITE'],
      },
      cycles: { sunday: 'A', weekday: 'II', psalterWeek: 4 },
      metadata: {
        country: 'US',
        diocese: 'dallas',
        locale: 'en-US',
        dataVersion: 'v2',
        lectionarySource: 'USCCB',
        lectionaryNumber: '423',
      },
    });
    expect(result.readings[0].text).toContain('Ezekiel 37:1');
    expect(result.metadata?.scriptureTextSource).toBe('NABRE');
  });

  it('returns Christmas reading sets from the service', async () => {
    const result = await getMassReadings({ date: '2026-12-25', country: 'US' });
    expect(result.readingSets).toHaveLength(4);
  });

  it('uses the local USCCB record for the Queenship of Mary', async () => {
    const result = await getMassReadings({
      date: '2026-08-22',
      country: 'US',
    });

    expect(result.celebration).toMatchObject({
      id: 'memorial-of-the-queenship-of-the-blessed-virgin-mary',
      name: 'Memorial of the Queenship of the Blessed Virgin Mary',
      grade: 'MEMORIAL',
      color: ['WHITE'],
    });
    expect(result.readings).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'FIRST_READING',
          citation: 'Ezekiel 43:1-7ab',
        }),
        expect.objectContaining({
          type: 'GOSPEL',
          citation: 'Matthew 23:1-12',
        }),
      ]),
    );
    expect(result.readings[0].text).toContain('Ezekiel 43:1');
  });

  it('maps local NABRE book text into the standard response body', async () => {
    const result = await getMassReadings({ date: '2026-08-21' });
    const ezekiel = result.readings.find(
      (reading) => reading.citation === 'Ez 37:1-14',
    );

    expect(ezekiel?.text).toContain('Ezekiel 37:1');
    expect(result.metadata?.scriptureTextSource).toBe('NABRE');
  });

  it('rejects malformed and impossible ISO dates', async () => {
    await expect(getMassReadings({ date: '2026-2-30' })).rejects.toMatchObject({
      code: 'INVALID_DATE',
    });
    await expect(getMassReadings({ date: '2026-02-30' })).rejects.toMatchObject(
      {
        code: 'INVALID_DATE',
      },
    );
  });

  it('uses the configured civil timezone for today', () => {
    expect(
      applicationToday(new Date('2026-08-21T04:30:00.000Z'), 'America/Chicago'),
    ).toBe('2026-08-20');
    expect(
      applicationToday(new Date('2026-08-21T05:30:00.000Z'), 'America/Chicago'),
    ).toBe('2026-08-21');
  });

  it('caches results using the full regional cache key', async () => {
    const service = new MassReadingsService();
    const first = await service.getMassReadings({
      date: '2026-08-21',
      country: 'US',
    });
    const second = await service.getMassReadings({
      date: '2026-08-21',
      country: 'US',
    });
    expect(second).toBe(first);
  });

  it('uses the local NABRE catalogue for citation validation', () => {
    const nabre = new NabreScriptureRepository();
    expect(nabre.supportsCitation('Ez 37:1-14')).toBe(true);
    expect(nabre.supportsCitation('Ezekiel 43:1-7ab')).toBe(true);
    expect(nabre.supportsCitation('1 Corinthians 1:1-9')).toBe(true);
    expect(nabre.supportsCitation('Mt 22:34-40')).toBe(true);
    expect(nabre.supportsCitation('Unknown 1:1')).toBe(false);
  });

  it('maps a cross-chapter citation from the individual local book file', async () => {
    const mapper = new NabreVerseMapper();
    const reading = await mapper.mapReading({
      type: 'FIRST_READING',
      citation: 'Gn 1:31—2:2',
    });

    expect(reading.text).toContain('Genesis 1:31');
    expect(reading.text).toContain('Genesis 2:2');
  });
});
