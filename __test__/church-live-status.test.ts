import { getChurchLiveStatus } from '@/lib/churches/live-status';

const churchTimeZone = 'America/Chicago';

describe('getChurchLiveStatus', () => {
  it('uses a one-hour duration when a service has no explicit end time', () => {
    const status = getChurchLiveStatus(
      [
        {
          id: 'mass-default-duration',
          serviceType: 'mass',
          weekday: 0,
          startTime: '10:00:00',
          endTime: null,
        },
      ],
      churchTimeZone,
      new Date('2026-07-26T15:30:00Z'),
    );

    expect(status.massInProgress).toBe(true);
    expect(status.activeSessions).toEqual([
      expect.objectContaining({
        serviceType: 'mass',
        weekday: 'sunday',
        usesDefaultOneHourDuration: true,
      }),
    ]);
  });

  it('reports overlapping Mass and confession independently', () => {
    const status = getChurchLiveStatus(
      [
        {
          id: 'mass',
          serviceType: 'mass',
          weekday: 0,
          startTime: '10:00:00',
          endTime: '11:30:00',
        },
        {
          id: 'confession',
          serviceType: 'confession',
          weekday: 0,
          startTime: '10:15:00',
          endTime: '10:45:00',
        },
      ],
      churchTimeZone,
      new Date('2026-07-26T15:30:00Z'),
    );

    expect(status.massInProgress).toBe(true);
    expect(status.confessionInProgress).toBe(true);
    expect(status.adorationInProgress).toBe(false);
    expect(status.activeSessions).toHaveLength(2);
  });

  it('keeps an overnight adoration active after midnight', () => {
    const status = getChurchLiveStatus(
      [
        {
          id: 'overnight-adoration',
          serviceType: 'adoration',
          weekday: 6,
          startTime: '23:30:00',
          endTime: '00:30:00',
        },
      ],
      churchTimeZone,
      new Date('2026-07-26T05:15:00Z'),
    );

    expect(status.adorationInProgress).toBe(true);
    expect(status.activeSessions[0]).toEqual(
      expect.objectContaining({ weekday: 'saturday' }),
    );
  });
});
