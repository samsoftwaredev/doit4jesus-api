import { commonReadings } from '@/liturgy/data/lectionary/commons';
import {
  cycleSpecificProperReadings,
  properReadings,
} from '@/liturgy/data/lectionary/proper';
import { temporalReadings } from '@/liturgy/data/lectionary/temporal';
import type {
  LectionaryEntry,
  LiturgicalCommon,
  LiturgicalSeason,
  SundayCycle,
  WeekdayCycle,
} from '@/liturgy/models';

export interface TemporalReadingsInput {
  season: LiturgicalSeason;
  week?: number;
  weekday: number;
  sundayCycle: SundayCycle;
  weekdayCycle: WeekdayCycle;
}

export interface LectionaryRepository {
  getProperReadings(
    eventId: string,
    sundayCycle: SundayCycle,
  ): LectionaryEntry | undefined;
  getTemporalReadings(input: TemporalReadingsInput): LectionaryEntry | undefined;
  getCommonReadings(common: LiturgicalCommon): LectionaryEntry[];
}

export class LocalLectionaryRepository implements LectionaryRepository {
  getProperReadings(eventId: string, sundayCycle: SundayCycle) {
    return cycleSpecificProperReadings[eventId]?.[sundayCycle] ?? properReadings[eventId];
  }

  getTemporalReadings(input: TemporalReadingsInput) {
    if (input.week === undefined) return undefined;
    const cycle = input.weekday === 0 ? input.sundayCycle : input.weekdayCycle;
    return temporalReadings[
      `${input.season}:${input.week}:${input.weekday}:${cycle}`
    ];
  }

  getCommonReadings(common: LiturgicalCommon) {
    return commonReadings[common] ?? [];
  }
}
