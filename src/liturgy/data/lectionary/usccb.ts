import sourceRecords from '@/liturgy/data/lectionary/usccb.json';
import type { UsccbDailyLectionaryEntry } from '@/liturgy/models';

/**
 * A versioned, checked-in snapshot generated from the licensed USCCB daily
 * readings pages. The API never fetches USCCB at request time.
 */
export const usccbDailyLectionary = new Map(
  (sourceRecords as UsccbDailyLectionaryEntry[]).map((entry) => [
    entry.date,
    entry,
  ]),
);
