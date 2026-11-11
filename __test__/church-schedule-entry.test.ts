import {
  type ScheduleEntry,
  addScheduleEntries,
  clearService,
  copyWeekday,
  dedupeEntries,
  formatEntryTime,
  formatTime12,
  groupByWeekday,
  hasMassTime,
  parseTimeList,
  removeScheduleEntry,
} from '../src/lib/churches/schedule-entry';

const starts = (text: string) =>
  parseTimeList(text).times.map((time) => time.startTime);

describe('parseTimeList', () => {
  it('parses comma, space, and "and" separated times', () => {
    expect(starts('7, 9, 11:30am and 5pm')).toEqual([
      '07:00',
      '09:00',
      '11:30',
      '17:00',
    ]);
    expect(starts('8:00 AM 10:00 AM\n12:30 pm')).toEqual([
      '08:00',
      '10:00',
      '12:30',
    ]);
  });

  it('accepts 24-hour, noon, and midnight', () => {
    expect(starts('19:00 noon midnight 0:30')).toEqual([
      '19:00',
      '12:00',
      '00:00',
      '00:30',
    ]);
  });

  it('resolves bare hours: 1-6 afternoon, 7-11 morning, 12 noon', () => {
    expect(starts('4 6 7 11 12')).toEqual([
      '16:00',
      '18:00',
      '07:00',
      '11:00',
      '12:00',
    ]);
  });

  it('lets an explicit am/pm override the bare-hour rule', () => {
    expect(starts('7pm 5am 12am 12pm')).toEqual([
      '19:00',
      '05:00',
      '00:00',
      '12:00',
    ]);
  });

  it('parses ranges and shares the end meridiem with the start', () => {
    expect(parseTimeList('4:00-4:45').times).toEqual([
      { startTime: '16:00', endTime: '16:45' },
    ]);
    expect(parseTimeList('4-4:45pm').times).toEqual([
      { startTime: '16:00', endTime: '16:45' },
    ]);
    expect(parseTimeList('11-12:30pm').times).toEqual([
      { startTime: '11:00', endTime: '12:30' },
    ]);
    expect(parseTimeList('3 – 4 pm').times).toEqual([
      { startTime: '15:00', endTime: '16:00' },
    ]);
  });

  it('reports invalid tokens and rejects backwards ranges', () => {
    const result = parseTimeList('9, banana, 25:00, 13pm, 5-4, 9:75');
    expect(result.times.map((time) => time.startTime)).toEqual(['09:00']);
    expect(result.invalid).toEqual(['banana', '25:00', '13pm', '5-4', '9:75']);
  });

  it('returns repeated start times once', () => {
    expect(starts('9, 9am, 09:00')).toEqual(['09:00']);
  });

  it('returns nothing for blank text', () => {
    expect(parseTimeList('  ')).toEqual({ times: [], invalid: [] });
  });
});

describe('schedule entry helpers', () => {
  const mass = (
    weekday: ScheduleEntry['weekday'],
    startTime: string,
  ): ScheduleEntry => ({
    serviceType: 'mass',
    weekday,
    startTime,
    endTime: null,
  });

  it('expands selected days x times and sorts the result', () => {
    const result = addScheduleEntries([], {
      serviceType: 'mass',
      weekdays: ['saturday', 'sunday'],
      times: parseTimeList('11, 7').times,
    });
    expect(
      result.map((entry) => `${entry.weekday} ${entry.startTime}`),
    ).toEqual([
      'sunday 07:00',
      'sunday 11:00',
      'saturday 07:00',
      'saturday 11:00',
    ]);
  });

  it('does not duplicate times already present and keeps the newer end time', () => {
    const existing = [mass('sunday', '09:00')];
    const result = addScheduleEntries(existing, {
      serviceType: 'mass',
      weekdays: ['sunday'],
      times: [{ startTime: '09:00', endTime: '10:00' }],
    });
    expect(result).toEqual([
      {
        serviceType: 'mass',
        weekday: 'sunday',
        startTime: '09:00',
        endTime: '10:00',
      },
    ]);
    expect(
      dedupeEntries([mass('sunday', '09:00'), mass('sunday', '09:00')]),
    ).toHaveLength(1);
  });

  it('groups one service by weekday and skips empty days', () => {
    const entries = [
      mass('sunday', '09:00'),
      mass('sunday', '07:00'),
      { ...mass('friday', '18:00'), serviceType: 'adoration' as const },
    ];
    expect(groupByWeekday(entries, 'mass')).toEqual([
      { weekday: 'sunday', entries: [entries[1], entries[0]] },
    ]);
    expect(groupByWeekday(entries, 'confession')).toEqual([]);
  });

  it('copies a weekday onto other days without touching other services', () => {
    const entries = [
      mass('monday', '07:00'),
      { ...mass('monday', '12:00'), serviceType: 'confession' as const },
    ];
    const result = copyWeekday(entries, 'mass', 'monday', [
      'tuesday',
      'wednesday',
      'monday',
    ]);
    expect(
      groupByWeekday(result, 'mass').map((group) => group.weekday),
    ).toEqual(['monday', 'tuesday', 'wednesday']);
    expect(
      groupByWeekday(result, 'confession').map((group) => group.weekday),
    ).toEqual(['monday']);
  });

  it('removes one entry, clears a service, and reports whether Mass exists', () => {
    const entries = [mass('sunday', '07:00'), mass('sunday', '09:00')];
    expect(removeScheduleEntry(entries, entries[0]!)).toEqual([entries[1]]);
    expect(hasMassTime(entries)).toBe(true);
    expect(hasMassTime(clearService(entries, 'mass'))).toBe(false);
  });

  it('formats times', () => {
    expect(formatTime12('00:05')).toBe('12:05 AM');
    expect(formatTime12('12:00')).toBe('12:00 PM');
    expect(formatTime12('19:30')).toBe('7:30 PM');
    expect(formatEntryTime({ startTime: '16:00', endTime: '16:45' })).toBe(
      '4:00 PM – 4:45 PM',
    );
  });
});
