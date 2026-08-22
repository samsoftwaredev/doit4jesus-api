import {
  type LiturgicalCalendarOptions,
  LiturgicalDayResolver,
} from '@/liturgy/calendar/LiturgicalDayResolver';

const defaultLiturgicalDayResolver = new LiturgicalDayResolver();

/** Reusable, date-only universal Roman-calendar resolution entry point. */
export function getLiturgicalDay(
  date: string,
  settings?: LiturgicalCalendarOptions,
) {
  return defaultLiturgicalDayResolver.resolve(date, settings);
}
