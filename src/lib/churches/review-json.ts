import {
  type ScheduleEntry,
  dedupeEntries,
  hasMassTime,
} from '@/lib/churches/schedule-entry';
import { importChurchEntrySchema } from '@/lib/schemas/church-subscription';

/** Church fields as the review dialog holds them. */
export type ReviewChurch = {
  name: string;
  address: {
    line1: string;
    line2: string | null;
    city: string;
    regionName: string | null;
    postalCode: string | null;
    countryCode: string;
  };
  timezone: string;
  latitude: number | null;
  longitude: number | null;
};

/** Same entry shape as the Import JSON tab, so the two always accept each other's JSON. */
export function toReviewJson(
  churchId: string,
  church: ReviewChurch,
  serviceTimes: ScheduleEntry[],
) {
  return {
    churchId,
    label: `${church.name}, ${church.address.line1}, ${church.address.city}`,
    church: {
      name: church.name,
      addressLine1: church.address.line1,
      addressLine2: church.address.line2,
      city: church.address.city,
      regionName: church.address.regionName,
      postalCode: church.address.postalCode,
      countryCode: church.address.countryCode,
      timezone: church.timezone,
      ...(church.latitude === null ? {} : { latitude: church.latitude }),
      ...(church.longitude === null ? {} : { longitude: church.longitude }),
    },
    serviceTimes: serviceTimes.map(
      ({ serviceType, weekday, startTime, endTime }) => ({
        serviceType,
        weekday,
        startTime,
        endTime,
      }),
    ),
  };
}

export function toReviewJsonText(
  churchId: string,
  church: ReviewChurch,
  serviceTimes: ScheduleEntry[],
) {
  return JSON.stringify(toReviewJson(churchId, church, serviceTimes), null, 2);
}

export type ParsedReviewJson =
  | { ok: true; church: ReviewChurch; serviceTimes: ScheduleEntry[] }
  | { ok: false; error: string };

/** Accepts one entry, or { churches: [entry] } with exactly one entry. Fields left out keep their current value. */
export function parseReviewJson(
  text: string,
  churchId: string,
  current: ReviewChurch,
): ParsedReviewJson {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch (error) {
    return {
      ok: false,
      error: `This is not valid JSON: ${(error as Error).message}`,
    };
  }
  if (raw && typeof raw === 'object' && 'churches' in raw) {
    const churches = (raw as { churches: unknown }).churches;
    if (!Array.isArray(churches) || churches.length !== 1) {
      return {
        ok: false,
        error: 'Provide exactly one church to review at a time.',
      };
    }
    raw = churches[0];
  }
  const parsed = importChurchEntrySchema.safeParse(raw);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues
        .slice(0, 3)
        .map((issue) => `${issue.path.join('.') || 'entry'}: ${issue.message}`)
        .join('; '),
    };
  }
  const entry = parsed.data;
  if (entry.churchId !== undefined && entry.churchId !== churchId) {
    return {
      ok: false,
      error: `churchId ${entry.churchId} is a different church than the one being reviewed (${churchId}).`,
    };
  }
  const next = entry.church ?? {};
  const serviceTimes = dedupeEntries(
    entry.serviceTimes.map((time) => ({
      serviceType: time.serviceType,
      weekday: time.weekday,
      startTime: time.startTime.slice(0, 5),
      endTime: time.endTime ? time.endTime.slice(0, 5) : null,
    })),
  );
  if (!hasMassTime(serviceTimes)) {
    return { ok: false, error: 'Add at least one Mass time.' };
  }
  return {
    ok: true,
    serviceTimes,
    church: {
      name: next.name ?? current.name,
      address: {
        line1: next.addressLine1 ?? current.address.line1,
        line2:
          next.addressLine2 !== undefined
            ? next.addressLine2
            : current.address.line2,
        city: next.city ?? current.address.city,
        regionName:
          next.regionName !== undefined
            ? next.regionName
            : current.address.regionName,
        postalCode:
          next.postalCode !== undefined
            ? next.postalCode
            : current.address.postalCode,
        countryCode: next.countryCode ?? current.address.countryCode,
      },
      timezone: next.timezone ?? current.timezone,
      latitude: next.latitude ?? current.latitude,
      longitude: next.longitude ?? current.longitude,
    },
  };
}

const describe = (entry: ScheduleEntry) =>
  `${entry.serviceType} ${entry.weekday} ${entry.startTime}${entry.endTime ? `–${entry.endTime}` : ''}`;

/** Human-readable list of service-time changes between two schedules. */
export function describeScheduleChanges(
  before: ScheduleEntry[],
  after: ScheduleEntry[],
) {
  const key = (entry: ScheduleEntry) =>
    `${entry.serviceType}|${entry.weekday}|${entry.startTime}|${entry.endTime ?? ''}`;
  const beforeKeys = new Set(before.map(key));
  const afterKeys = new Set(after.map(key));
  return [
    ...after
      .filter((entry) => !beforeKeys.has(key(entry)))
      .map((entry) => `+ ${describe(entry)}`),
    ...before
      .filter((entry) => !afterKeys.has(key(entry)))
      .map((entry) => `− ${describe(entry)}`),
  ];
}
