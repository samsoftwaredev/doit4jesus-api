import { ApiError } from '@/lib/api/errors';
import { LiturgicalDayResolver } from '@/liturgy/calendar/LiturgicalDayResolver';
import { LocalLectionaryRepository } from '@/liturgy/lectionary/LectionaryRepository';
import { LectionaryResolver } from '@/liturgy/lectionary/LectionaryResolver';
import type { DailyMassReadings } from '@/liturgy/models';
import { NabreVerseMapper } from '@/liturgy/scripture/NabreVerseMapper';

const DATA_VERSION = 'v1';
const DEFAULT_TIMEZONE = 'America/Chicago';
const CACHE_TTL_MILLISECONDS = 5 * 60 * 1_000;

export interface GetMassReadingsInput {
  date: string;
  country?: string;
  diocese?: string;
  locale?: string;
  includeVerseText?: boolean;
}

export interface MassReadingsCache {
  get(key: string): DailyMassReadings | undefined;
  set(key: string, value: DailyMassReadings, ttlMilliseconds: number): void;
}

type CachedValue = { value: DailyMassReadings; expiresAt: number };

export class InMemoryMassReadingsCache implements MassReadingsCache {
  private readonly values = new Map<string, CachedValue>();

  get(key: string) {
    const cached = this.values.get(key);
    if (!cached) return undefined;
    if (cached.expiresAt <= Date.now()) {
      this.values.delete(key);
      return undefined;
    }
    return cached.value;
  }

  set(key: string, value: DailyMassReadings, ttlMilliseconds: number) {
    this.values.set(key, { value, expiresAt: Date.now() + ttlMilliseconds });
  }
}

function isValidCalendarDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return (
    !Number.isNaN(parsed.valueOf()) &&
    parsed.toISOString().slice(0, 10) === value
  );
}

function normalizeInput(input: GetMassReadingsInput): GetMassReadingsInput {
  if (!isValidCalendarDate(input.date)) {
    throw new ApiError(400, 'INVALID_DATE', 'Date must use YYYY-MM-DD format.');
  }

  const country = input.country?.trim().toUpperCase();
  if (country && !/^[A-Z]{2}$/.test(country)) {
    throw new ApiError(
      400,
      'INVALID_COUNTRY',
      'country must use a two-letter ISO country code.',
    );
  }

  const diocese = input.diocese?.trim().toLowerCase();
  if (diocese && !/^[a-z0-9]+(?:[ -][a-z0-9]+)*$/.test(diocese)) {
    throw new ApiError(
      400,
      'INVALID_DIOCESE',
      'diocese must contain letters, numbers, spaces, or hyphens only.',
    );
  }

  const locale = input.locale?.trim();
  if (locale) {
    try {
      Intl.getCanonicalLocales(locale);
    } catch {
      throw new ApiError(
        400,
        'INVALID_LOCALE',
        'locale must be a valid BCP 47 language tag.',
      );
    }
  }

  return {
    date: input.date,
    country,
    diocese,
    locale,
    includeVerseText: input.includeVerseText !== false,
  };
}

function cacheKey(input: GetMassReadingsInput) {
  return [
    'mass-readings',
    input.date,
    input.country ?? '-',
    input.diocese ?? '-',
    input.locale ?? '-',
    input.includeVerseText ? 'verse-text' : 'references-only',
    DATA_VERSION,
  ].join(':');
}

export function applicationToday(
  now = new Date(),
  timezone = process.env.LITURGY_TIMEZONE ?? DEFAULT_TIMEZONE,
) {
  try {
    const values = Object.fromEntries(
      new Intl.DateTimeFormat('en-CA', {
        timeZone: timezone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      })
        .formatToParts(now)
        .filter((part) => part.type !== 'literal')
        .map((part) => [part.type, part.value]),
    );
    return `${values.year}-${values.month}-${values.day}`;
  } catch {
    throw new ApiError(
      500,
      'LITURGY_RESOLUTION_ERROR',
      'LITURGY_TIMEZONE must be a valid IANA timezone.',
    );
  }
}

export class MassReadingsService {
  constructor(
    private readonly calendar = new LiturgicalDayResolver(),
    private readonly lectionary = new LectionaryResolver(
      new LocalLectionaryRepository(),
    ),
    private readonly cache: MassReadingsCache = new InMemoryMassReadingsCache(),
    private readonly verseMapper = new NabreVerseMapper(),
  ) {}

  async getMassReadings(
    input: GetMassReadingsInput,
  ): Promise<DailyMassReadings> {
    const normalized = normalizeInput(input);
    const key = cacheKey(normalized);
    const cached = this.cache.get(key);
    if (cached) return cached;

    const day = this.calendar.resolve(normalized.date, {
      country: normalized.country,
      diocese: normalized.diocese,
    });
    const resolution = this.lectionary.resolve(day);
    if (!resolution.primary) {
      throw new ApiError(
        404,
        'READINGS_NOT_FOUND',
        `No curated lectionary entry is available for ${day.primaryCelebration.name}.`,
        {
          date: day.date,
          celebrationId: day.primaryCelebration.id,
          dataVersion: DATA_VERSION,
        },
      );
    }

    const readingSets =
      normalized.includeVerseText !== false
        ? await Promise.all(
            resolution.readingSets.map(async (readingSet) => ({
              ...readingSet,
              readings: await this.verseMapper.mapReadings(readingSet.readings),
            })),
          )
        : resolution.readingSets;
    const primary = readingSets[0];
    if (!primary) {
      throw new ApiError(
        404,
        'READINGS_NOT_FOUND',
        'No readings are available for this date.',
      );
    }

    const result: DailyMassReadings = {
      date: day.date,
      celebration: {
        id: day.primaryCelebration.id,
        name: day.primaryCelebration.name,
        grade: day.primaryCelebration.grade,
        season: day.season,
        color: day.primaryCelebration.colors,
      },
      cycles: {
        sunday: day.sundayCycle,
        weekday: day.weekdayCycle,
        psalterWeek: day.psalterWeek,
      },
      readings: primary.readings,
      ...(readingSets.length > 1 ? { readingSets } : {}),
      metadata: {
        ...(normalized.country ? { country: normalized.country } : {}),
        ...(normalized.diocese ? { diocese: normalized.diocese } : {}),
        ...(normalized.locale ? { locale: normalized.locale } : {}),
        dataVersion: DATA_VERSION,
        scriptureTextSource: 'NABRE',
      },
    };
    this.cache.set(key, result, CACHE_TTL_MILLISECONDS);
    return result;
  }
}

const defaultMassReadingsService = new MassReadingsService();

export async function getMassReadings(input: GetMassReadingsInput) {
  return defaultMassReadingsService.getMassReadings(input);
}
