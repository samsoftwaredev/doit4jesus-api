export const scriptureReadingTypes = [
  'FIRST_READING',
  'RESPONSORIAL_PSALM',
  'SECOND_READING',
  'EPISTLE',
  'GOSPEL_ACCLAMATION',
  'GOSPEL',
  'OTHER',
] as const;

export type ScriptureReadingType = (typeof scriptureReadingTypes)[number];
export type LiturgicalSeason =
  | 'ADVENT'
  | 'CHRISTMAS'
  | 'ORDINARY_TIME'
  | 'LENT'
  | 'EASTER';
export type LiturgicalGrade =
  | 'SOLEMNITY'
  | 'FEAST'
  | 'MEMORIAL'
  | 'OPTIONAL_MEMORIAL'
  | 'SUNDAY'
  | 'WEEKDAY';
export type LiturgicalColor = 'WHITE' | 'GREEN' | 'VIOLET' | 'RED' | 'ROSE';
export type SundayCycle = 'A' | 'B' | 'C';
export type WeekdayCycle = 'I' | 'II';
export type ReadingSetLabel =
  | 'DEFAULT'
  | 'VIGIL'
  | 'EXTENDED_VIGIL'
  | 'NIGHT'
  | 'DAWN'
  | 'DAY';
export type ReadingSelectionRule =
  | 'REQUIRED_PROPER'
  | 'OPTIONAL_PROPER'
  | 'WEEKDAY'
  | 'COMMON'
  | 'MIXED';
export type LiturgicalCommon =
  | 'MARTYRS'
  | 'PASTORS'
  | 'DOCTORS'
  | 'VIRGINS'
  | 'HOLY_MEN_AND_WOMEN'
  | 'BLESSED_VIRGIN_MARY';

export interface CanonicalReference {
  book: string;
  chapterStart: number;
  verseStart?: number;
  chapterEnd?: number;
  verseEnd?: number;
}

export interface ScriptureReading {
  type: ScriptureReadingType;
  citation: string;
  canonicalReference?: CanonicalReference;
  optional?: boolean;
  /** Present only when the caller opts into local NABRE verse text. */
  text?: string;
}

export interface ReadingSet {
  id: string;
  label: ReadingSetLabel;
  readings: ScriptureReading[];
  /** Explains why this set is available when a day has more than one option. */
  selectionRule?: ReadingSelectionRule;
}

export interface LiturgicalCelebration {
  id: string;
  name: string;
  grade: LiturgicalGrade;
  colors: LiturgicalColor[];
  readingSelectionRule: ReadingSelectionRule;
  common?: LiturgicalCommon;
}

export interface LiturgicalDay {
  date: string;
  primaryCelebration: LiturgicalCelebration;
  season: LiturgicalSeason;
  week?: number;
  weekday: number;
  sundayCycle: SundayCycle;
  weekdayCycle: WeekdayCycle;
  psalterWeek?: 1 | 2 | 3 | 4;
  country?: string;
  diocese?: string;
}

export interface DailyMassReadings {
  date: string;
  celebration: {
    id: string;
    name: string;
    grade: LiturgicalGrade;
    season: LiturgicalSeason;
    color: LiturgicalColor[];
  };
  cycles: {
    sunday: SundayCycle;
    weekday: WeekdayCycle;
    psalterWeek?: 1 | 2 | 3 | 4;
  };
  readings: ScriptureReading[];
  readingSets?: ReadingSet[];
  metadata?: {
    country?: string;
    diocese?: string;
    locale?: string;
    dataVersion: string;
    scriptureTextSource?: 'NABRE';
    /** True when at least one cited passage is not present in local Bible files. */
    scriptureTextUnavailable?: boolean;
    lectionarySource?: 'USCCB' | 'LOCAL';
    lectionaryNumber?: string;
    sourceUrl?: string;
  };
}

export interface LectionaryEntry {
  eventId?: string;
  selectionRule: ReadingSelectionRule;
  readingSets: ReadingSet[];
  common?: LiturgicalCommon;
}

/** A date-specific USCCB lectionary record imported during data generation. */
export interface UsccbDailyLectionaryEntry {
  date: string;
  celebration: LiturgicalCelebration;
  lectionaryNumber?: string;
  readingSets: ReadingSet[];
  sourceUrl: string;
}

/**
 * A future Bible-text integration point. The calendar and lectionary never
 * depend on it; this feature intentionally returns references only.
 */
export interface ScriptureTextProvider {
  getPassage(citation: string, translation: string): Promise<string>;
}
