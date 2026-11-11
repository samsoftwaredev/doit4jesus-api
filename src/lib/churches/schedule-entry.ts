/**
 * Pure helpers for entering many recurring service times at once: free-text
 * time parsing, expanding days x times, grouping for display, and de-duplication.
 * No React or server imports so both the admin UI and tests can use it.
 */

export const scheduleServiceTypes = [
  'mass',
  'confession',
  'adoration',
] as const;
export const scheduleWeekdays = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const;

export type ScheduleServiceType = (typeof scheduleServiceTypes)[number];
export type ScheduleWeekday = (typeof scheduleWeekdays)[number];

export type ScheduleEntry = {
  serviceType: ScheduleServiceType;
  weekday: ScheduleWeekday;
  /** 24-hour HH:MM. */
  startTime: string;
  /** 24-hour HH:MM or null. */
  endTime: string | null;
};

export type ParsedTime = { startTime: string; endTime: string | null };

export type ParsedTimeList = {
  times: ParsedTime[];
  /** Tokens that could not be understood, in input order. */
  invalid: string[];
};

export const weekdayPresets: { label: string; weekdays: ScheduleWeekday[] }[] =
  [
    { label: 'Every day', weekdays: [...scheduleWeekdays] },
    {
      label: 'Weekdays',
      weekdays: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    },
    { label: 'Weekend', weekdays: ['saturday', 'sunday'] },
    { label: 'Sunday', weekdays: ['sunday'] },
  ];

type Meridiem = 'am' | 'pm';
type Clock = { hour: number; minute: number };

const TIME_TOKEN = /^(\d{1,2})(?::(\d{2}))?(am|pm|a|p)?$/;

function meridiemOf(value: string | undefined): Meridiem | null {
  if (!value) return null;
  return value.startsWith('p') ? 'pm' : 'am';
}

function toClock(
  token: string,
  forcedMeridiem?: Meridiem,
): { clock: Clock; explicit: Meridiem | null } | null {
  if (token === 'noon')
    return { clock: { hour: 12, minute: 0 }, explicit: null };
  if (token === 'midnight')
    return { clock: { hour: 0, minute: 0 }, explicit: null };
  const match = TIME_TOKEN.exec(token);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = match[2] === undefined ? 0 : Number(match[2]);
  if (minute > 59) return null;
  const explicit = meridiemOf(match[3]);
  const meridiem = explicit ?? forcedMeridiem ?? null;

  if (meridiem) {
    if (hour < 1 || hour > 12) return null;
    return {
      clock: { hour: (hour % 12) + (meridiem === 'pm' ? 12 : 0), minute },
      explicit,
    };
  }
  if (hour > 23) return null;
  // Bare hours: 13-23 are 24-hour, 7-11 are morning, 12 is noon, 1-6 are afternoon/evening.
  const resolved = hour >= 1 && hour <= 6 ? hour + 12 : hour;
  return { clock: { hour: resolved, minute }, explicit: null };
}

function formatClock({ hour, minute }: Clock) {
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function minutesOf({ hour, minute }: Clock) {
  return hour * 60 + minute;
}

function parseToken(token: string): ParsedTime | null {
  const parts = token.split('-');
  if (parts.length === 1) {
    const single = toClock(token);
    return single
      ? { startTime: formatClock(single.clock), endTime: null }
      : null;
  }
  if (parts.length !== 2 || !parts[0] || !parts[1]) return null;

  const end = toClock(parts[1]);
  if (!end) return null;
  // A start without am/pm borrows the end's ("4-4:45pm"), unless that puts it after the end ("11-12:30pm").
  let start = toClock(parts[0], end.explicit ?? undefined);
  if (start && !/(am|pm|a|p)$/.test(parts[0]) && end.explicit) {
    if (minutesOf(start.clock) >= minutesOf(end.clock)) {
      start = toClock(parts[0], end.explicit === 'pm' ? 'am' : 'pm');
    }
  }
  if (!start || minutesOf(start.clock) >= minutesOf(end.clock)) return null;
  return {
    startTime: formatClock(start.clock),
    endTime: formatClock(end.clock),
  };
}

/**
 * Parses text such as "7, 9, 11:30am and 5pm" or "4:00-4:45" into times.
 * Accepts 24-hour and am/pm forms, `noon`/`midnight`, and start-end ranges.
 * Repeated start times are returned once.
 */
export function parseTimeList(text: string): ParsedTimeList {
  const normalized = text
    .toLowerCase()
    .replace(/[‒-―−]/g, '-')
    .replace(/\b(a|p)\.m\.?/g, '$1m')
    .replace(/\band\b|&/g, ',')
    .replace(/(\d)\s+(am|pm)\b/g, '$1$2')
    .replace(/\s*-\s*/g, '-');

  const times: ParsedTime[] = [];
  const invalid: string[] = [];
  const seen = new Set<string>();
  for (const token of normalized.split(/[\s,;]+/).filter(Boolean)) {
    const parsed = parseToken(token);
    if (!parsed) {
      invalid.push(token);
    } else if (!seen.has(parsed.startTime)) {
      seen.add(parsed.startTime);
      times.push(parsed);
    }
  }
  return { times, invalid };
}

/** Formats a 24-hour HH:MM value as "7:00 AM". */
export function formatTime12(value: string) {
  const [hourText, minuteText] = value.split(':');
  const hour = Number(hourText);
  if (Number.isNaN(hour) || !minuteText) return value;
  return `${hour % 12 === 0 ? 12 : hour % 12}:${minuteText} ${hour >= 12 ? 'PM' : 'AM'}`;
}

/** Formats an entry's time, including its end when present. */
export function formatEntryTime(
  entry: Pick<ScheduleEntry, 'startTime' | 'endTime'>,
) {
  return entry.endTime
    ? `${formatTime12(entry.startTime)} – ${formatTime12(entry.endTime)}`
    : formatTime12(entry.startTime);
}

function entryKey(entry: ScheduleEntry) {
  return `${entry.serviceType}|${entry.weekday}|${entry.startTime}`;
}

/** Sorts by service type, weekday (Sunday first), then start time. */
export function sortEntries(entries: ScheduleEntry[]) {
  return [...entries].sort(
    (left, right) =>
      scheduleServiceTypes.indexOf(left.serviceType) -
        scheduleServiceTypes.indexOf(right.serviceType) ||
      scheduleWeekdays.indexOf(left.weekday) -
        scheduleWeekdays.indexOf(right.weekday) ||
      left.startTime.localeCompare(right.startTime),
  );
}

/** Merges entries, keeping one per (service, weekday, start); later entries win. */
export function dedupeEntries(entries: ScheduleEntry[]) {
  const byKey = new Map<string, ScheduleEntry>();
  for (const entry of entries) byKey.set(entryKey(entry), entry);
  return sortEntries([...byKey.values()]);
}

/** Adds one entry per selected weekday x parsed time to an existing schedule. */
export function addScheduleEntries(
  existing: ScheduleEntry[],
  input: {
    serviceType: ScheduleServiceType;
    weekdays: ScheduleWeekday[];
    times: ParsedTime[];
  },
) {
  const added = input.weekdays.flatMap((weekday) =>
    input.times.map((time) => ({
      serviceType: input.serviceType,
      weekday,
      startTime: time.startTime,
      endTime: time.endTime,
    })),
  );
  return dedupeEntries([...existing, ...added]);
}

/** Removes one exact (service, weekday, start) entry. */
export function removeScheduleEntry(
  entries: ScheduleEntry[],
  target: ScheduleEntry,
) {
  const key = entryKey(target);
  return entries.filter((entry) => entryKey(entry) !== key);
}

/** Removes every entry of one service type. */
export function clearService(
  entries: ScheduleEntry[],
  serviceType: ScheduleServiceType,
) {
  return entries.filter((entry) => entry.serviceType !== serviceType);
}

/** Copies one service's times from a weekday onto other weekdays. */
export function copyWeekday(
  entries: ScheduleEntry[],
  serviceType: ScheduleServiceType,
  from: ScheduleWeekday,
  to: ScheduleWeekday[],
) {
  const source = entries.filter(
    (entry) => entry.serviceType === serviceType && entry.weekday === from,
  );
  const copies = to
    .filter((weekday) => weekday !== from)
    .flatMap((weekday) => source.map((entry) => ({ ...entry, weekday })));
  return dedupeEntries([...entries, ...copies]);
}

/** Groups one service's entries by weekday, Sunday first, skipping empty days. */
export function groupByWeekday(
  entries: ScheduleEntry[],
  serviceType: ScheduleServiceType,
) {
  return scheduleWeekdays
    .map((weekday) => ({
      weekday,
      entries: entries
        .filter(
          (entry) =>
            entry.serviceType === serviceType && entry.weekday === weekday,
        )
        .sort((left, right) => left.startTime.localeCompare(right.startTime)),
    }))
    .filter((group) => group.entries.length > 0);
}

/** A schedule can be saved only when it has at least one Mass time. */
export function hasMassTime(entries: ScheduleEntry[]) {
  return entries.some((entry) => entry.serviceType === 'mass');
}
