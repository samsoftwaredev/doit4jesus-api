import type {
  LiturgicalCelebration,
  LiturgicalColor,
  LiturgicalDay,
  LiturgicalGrade,
  LiturgicalSeason,
  ReadingSelectionRule,
  SundayCycle,
} from '@/liturgy/models';

export interface LiturgicalCalendarOptions {
  country?: string;
  diocese?: string;
}

type DateParts = { year: number; month: number; day: number };

const DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1_000;
const weekdayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

function utcDate({ year, month, day }: DateParts) {
  return new Date(Date.UTC(year, month - 1, day));
}

function formatDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function addDays(date: Date, days: number) {
  const value = new Date(date.valueOf());
  value.setUTCDate(value.getUTCDate() + days);
  return value;
}

function compareDates(left: Date, right: Date) {
  return left.valueOf() - right.valueOf();
}

function sameDate(left: Date, right: Date) {
  return compareDates(left, right) === 0;
}

function daysBetween(start: Date, end: Date) {
  return Math.round((end.valueOf() - start.valueOf()) / DAY_IN_MILLISECONDS);
}

function sundayOnOrAfter(date: Date) {
  return addDays(date, (7 - date.getUTCDay()) % 7);
}

function sundayOnOrBefore(date: Date) {
  return addDays(date, -date.getUTCDay());
}

function ordinal(value: number) {
  const suffix = value % 10 === 1 && value % 100 !== 11
    ? 'st'
    : value % 10 === 2 && value % 100 !== 12
      ? 'nd'
      : value % 10 === 3 && value % 100 !== 13
        ? 'rd'
        : 'th';
  return `${value}${suffix}`;
}

function celebration(
  id: string,
  name: string,
  grade: LiturgicalGrade,
  colors: LiturgicalColor[],
  readingSelectionRule: ReadingSelectionRule,
): LiturgicalCelebration {
  return { id, name, grade, colors, readingSelectionRule };
}

/** Gregorian computus. Dates are always kept as UTC date-only values. */
export function easterSunday(year: number) {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return utcDate({ year, month, day });
}

export function firstSundayOfAdvent(year: number) {
  return sundayOnOrAfter(utcDate({ year, month: 11, day: 27 }));
}

function sundayCycle(liturgicalYear: number): SundayCycle {
  const cycles: SundayCycle[] = ['A', 'B', 'C'];
  return cycles[((liturgicalYear - 2026) % 3 + 3) % 3];
}

function epiphany(year: number, country?: string) {
  if (country === 'US') return sundayOnOrAfter(utcDate({ year, month: 1, day: 2 }));
  return utcDate({ year, month: 1, day: 6 });
}

function baptismOfTheLord(year: number, country?: string) {
  const epiphanyDate = epiphany(year, country);
  return addDays(epiphanyDate, 7 - epiphanyDate.getUTCDay());
}

function fixedCelebration(date: Date): LiturgicalCelebration | undefined {
  const month = date.getUTCMonth() + 1;
  const day = date.getUTCDate();
  const fixed: Record<string, LiturgicalCelebration> = {
    '1-1': celebration('mary-mother-of-god', 'Mary, the Holy Mother of God', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '3-19': celebration('saint-joseph', 'Saint Joseph, Spouse of the Blessed Virgin Mary', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '3-25': celebration('annunciation', 'The Annunciation of the Lord', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '6-24': celebration('nativity-of-saint-john-the-baptist', 'The Nativity of Saint John the Baptist', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '6-29': celebration('saints-peter-and-paul', 'Saints Peter and Paul, Apostles', 'SOLEMNITY', ['RED'], 'REQUIRED_PROPER'),
    '8-6': celebration('transfiguration', 'The Transfiguration of the Lord', 'FEAST', ['WHITE'], 'REQUIRED_PROPER'),
    '8-15': celebration('assumption', 'The Assumption of the Blessed Virgin Mary', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '8-21': celebration('saint-pius-x', 'Memorial of Saint Pius X, Pope', 'MEMORIAL', ['WHITE'], 'WEEKDAY'),
    '8-28': celebration('saint-augustine', 'Memorial of Saint Augustine, Bishop and Doctor of the Church', 'MEMORIAL', ['WHITE'], 'OPTIONAL_PROPER'),
    '10-1': celebration('saint-therese-of-lisieux', 'Memorial of Saint Thérèse of the Child Jesus, Virgin and Doctor of the Church', 'MEMORIAL', ['WHITE'], 'OPTIONAL_PROPER'),
    '11-1': celebration('all-saints', 'All Saints', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '12-8': celebration('immaculate-conception', 'The Immaculate Conception of the Blessed Virgin Mary', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '12-25': celebration('christmas', 'The Nativity of the Lord (Christmas)', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
  };
  return fixed[`${month}-${day}`];
}

function specialCelebration(
  date: Date,
  easter: Date,
  country: string | undefined,
): LiturgicalCelebration | undefined {
  const offset = daysBetween(easter, date);
  const variable: Record<string, LiturgicalCelebration> = {
    '-46': celebration('ash-wednesday', 'Ash Wednesday', 'WEEKDAY', ['VIOLET'], 'REQUIRED_PROPER'),
    '-7': celebration('palm-sunday', 'Palm Sunday of the Passion of the Lord', 'SUNDAY', ['RED'], 'REQUIRED_PROPER'),
    '-3': celebration('holy-thursday', 'Holy Thursday - Mass of the Lord’s Supper', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '-2': celebration('good-friday', 'Friday of the Passion of the Lord', 'SOLEMNITY', ['RED'], 'REQUIRED_PROPER'),
    '-1': celebration('easter-vigil', 'The Easter Vigil in the Holy Night', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '0': celebration('easter-sunday', 'Easter Sunday of the Resurrection of the Lord', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
    '49': celebration('pentecost', 'Pentecost Sunday', 'SOLEMNITY', ['RED'], 'REQUIRED_PROPER'),
    '68': celebration('sacred-heart', 'The Most Sacred Heart of Jesus', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER'),
  };

  if (sameDate(date, addDays(easter, country === 'US' ? 42 : 39))) {
    return celebration('ascension', 'The Ascension of the Lord', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER');
  }
  if (sameDate(date, addDays(easter, country === 'US' ? 63 : 60))) {
    return celebration('corpus-christi', 'The Most Holy Body and Blood of Christ', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER');
  }
  if (offset === -46) return variable['-46'];
  if (offset === -7) return variable['-7'];
  if (offset >= -6 && offset <= -1) return variable[String(offset)];
  if (offset === 0 || offset === 49 || offset === 68) return variable[String(offset)];
  return undefined;
}

function seasonForDate(date: Date, easter: Date, advent: Date, country?: string): LiturgicalSeason {
  const year = date.getUTCFullYear();
  const baptism = baptismOfTheLord(year, country);
  const ashWednesday = addDays(easter, -46);
  const pentecost = addDays(easter, 49);

  if (date.getUTCMonth() === 11 && date.getUTCDate() >= 25) return 'CHRISTMAS';
  if (compareDates(date, advent) >= 0) return 'ADVENT';
  if (compareDates(date, baptism) <= 0) return 'CHRISTMAS';
  if (compareDates(date, ashWednesday) >= 0 && compareDates(date, easter) < 0) return 'LENT';
  if (compareDates(date, easter) >= 0 && compareDates(date, pentecost) <= 0) return 'EASTER';
  return 'ORDINARY_TIME';
}

function weekForDate(date: Date, season: LiturgicalSeason, easter: Date, advent: Date, country?: string) {
  const year = date.getUTCFullYear();
  if (season === 'ADVENT') return Math.floor(daysBetween(advent, date) / 7) + 1;
  if (season === 'EASTER') return Math.floor(daysBetween(easter, date) / 7) + 1;
  if (season === 'LENT') {
    const ashWednesday = addDays(easter, -46);
    if (compareDates(date, addDays(ashWednesday, 4)) <= 0) return 0;
    return Math.floor(daysBetween(sundayOnOrAfter(ashWednesday), date) / 7) + 1;
  }
  if (season !== 'ORDINARY_TIME') return undefined;

  const baptism = baptismOfTheLord(year, country);
  const ashWednesday = addDays(easter, -46);
  if (compareDates(date, ashWednesday) < 0) {
    return Math.floor(daysBetween(addDays(baptism, 1), date) / 7) + 1;
  }

  const lastOrdinarySunday = sundayOnOrBefore(addDays(advent, -1));
  const currentSunday = sundayOnOrBefore(date);
  return 34 - Math.floor(daysBetween(currentSunday, lastOrdinarySunday) / 7);
}

function defaultCelebration(
  date: Date,
  season: LiturgicalSeason,
  week: number | undefined,
): LiturgicalCelebration {
  const weekday = date.getUTCDay();
  const dayName = weekdayNames[weekday];
  const colors: Record<LiturgicalSeason, LiturgicalColor[]> = {
    ADVENT: ['VIOLET'],
    CHRISTMAS: ['WHITE'],
    ORDINARY_TIME: ['GREEN'],
    LENT: ['VIOLET'],
    EASTER: ['WHITE'],
  };

  if (weekday === 0) {
    if (season === 'ORDINARY_TIME') {
      return celebration(
        `ordinary-time-week-${week}-sunday`,
        `${ordinal(week ?? 1)} Sunday in Ordinary Time`,
        'SUNDAY',
        colors[season],
        'WEEKDAY',
      );
    }
    return celebration(
      `${season.toLowerCase()}-week-${week}-sunday`,
      `${ordinal(week ?? 1)} Sunday of ${season.charAt(0) + season.slice(1).toLowerCase()}`,
      'SUNDAY',
      colors[season],
      'WEEKDAY',
    );
  }

  if (season === 'ORDINARY_TIME') {
    return celebration(
      `ordinary-time-week-${week}-${dayName.toLowerCase()}`,
      `${dayName} of the ${ordinal(week ?? 1)} Week in Ordinary Time`,
      'WEEKDAY',
      colors[season],
      'WEEKDAY',
    );
  }
  return celebration(
    `${season.toLowerCase()}-week-${week}-${dayName.toLowerCase()}`,
    `${dayName} of the ${ordinal(week ?? 1)} Week of ${season.charAt(0) + season.slice(1).toLowerCase()}`,
    'WEEKDAY',
    colors[season],
    'WEEKDAY',
  );
}

function psalterWeek(week: number | undefined): 1 | 2 | 3 | 4 | undefined {
  if (!week || week < 1) return undefined;
  return (((week - 1) % 4) + 1) as 1 | 2 | 3 | 4;
}

export class LiturgicalDayResolver {
  resolve(date: string, options: LiturgicalCalendarOptions = {}): LiturgicalDay {
    const [year, month, day] = date.split('-').map(Number);
    const value = utcDate({ year, month, day });
    const easter = easterSunday(year);
    const advent = firstSundayOfAdvent(year);
    const liturgicalYear = compareDates(value, advent) >= 0 ? year + 1 : year;
    const cycle = sundayCycle(liturgicalYear);
    const season = seasonForDate(value, easter, advent, options.country);
    const week = weekForDate(value, season, easter, advent, options.country);
    const special = specialCelebration(value, easter, options.country);
    const epiphanyCelebration = sameDate(value, epiphany(year, options.country))
      ? celebration('epiphany', 'The Epiphany of the Lord', 'SOLEMNITY', ['WHITE'], 'REQUIRED_PROPER')
      : undefined;
    const fixed = fixedCelebration(value);

    return {
      date: formatDate(value),
      primaryCelebration: special ?? epiphanyCelebration ?? fixed ?? defaultCelebration(value, season, week),
      season,
      week,
      weekday: value.getUTCDay(),
      sundayCycle: cycle,
      weekdayCycle: year % 2 === 0 ? 'II' : 'I',
      psalterWeek: psalterWeek(week),
      country: options.country,
      diocese: options.diocese,
    };
  }
}
