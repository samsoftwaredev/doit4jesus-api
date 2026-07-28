export type ChurchServiceType = 'mass' | 'confession' | 'adoration';

export type ChurchServiceTime = {
  id: string;
  serviceType: ChurchServiceType;
  weekday: number;
  startTime: string;
  endTime: string | null;
};

const weekdayNames = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const;

function localTimeToMinutes(value: string): number {
  const match = value.match(/^(\d{2}):(\d{2})/);
  if (!match) throw new Error(`Invalid local time: ${value}`);

  return Number(match[1]) * 60 + Number(match[2]);
}

function toHourMinute(value: string): string {
  return value.slice(0, 5);
}

function localClock(timeZone: string, now: Date) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const values = Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  );
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(
    values.weekday,
  );

  if (weekday < 0)
    throw new Error(`Could not calculate weekday for ${timeZone}.`);

  return {
    weekday,
    minute: (Number(values.hour) % 24) * 60 + Number(values.minute),
  };
}

function isActive(
  serviceTime: ChurchServiceTime,
  currentWeekday: number,
  currentMinute: number,
) {
  const startMinute = localTimeToMinutes(serviceTime.startTime);
  const suppliedEndMinute = serviceTime.endTime
    ? localTimeToMinutes(serviceTime.endTime)
    : null;
  const endMinute =
    suppliedEndMinute === null
      ? startMinute + 60
      : suppliedEndMinute <= startMinute
        ? suppliedEndMinute + 24 * 60
        : suppliedEndMinute;

  if (serviceTime.weekday === currentWeekday) {
    return currentMinute >= startMinute && currentMinute < endMinute;
  }

  const previousWeekday = (currentWeekday + 6) % 7;
  return (
    serviceTime.weekday === previousWeekday &&
    endMinute > 24 * 60 &&
    currentMinute + 24 * 60 < endMinute
  );
}

export function getChurchLiveStatus(
  serviceTimes: ChurchServiceTime[],
  timeZone: string,
  now = new Date(),
) {
  const clock = localClock(timeZone, now);
  const activeSessions = serviceTimes
    .filter((serviceTime) => isActive(serviceTime, clock.weekday, clock.minute))
    .map((serviceTime) => ({
      id: serviceTime.id,
      serviceType: serviceTime.serviceType,
      weekday: weekdayNames[serviceTime.weekday],
      startTime: toHourMinute(serviceTime.startTime),
      endTime: serviceTime.endTime ? toHourMinute(serviceTime.endTime) : null,
      usesDefaultOneHourDuration: serviceTime.endTime === null,
    }));

  return {
    evaluatedAt: now.toISOString(),
    timeZone,
    massInProgress: activeSessions.some(
      (session) => session.serviceType === 'mass',
    ),
    confessionInProgress: activeSessions.some(
      (session) => session.serviceType === 'confession',
    ),
    adorationInProgress: activeSessions.some(
      (session) => session.serviceType === 'adoration',
    ),
    activeSessions,
  };
}

export function weekdayName(weekday: number) {
  return weekdayNames[weekday];
}
