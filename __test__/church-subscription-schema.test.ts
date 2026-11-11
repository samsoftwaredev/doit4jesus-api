import {
  createChurchSubscriptionSchema,
  reviewChurchScheduleSchema,
  upcomingChurchServicesQuerySchema,
} from '@/lib/schemas/church-subscription';

describe('church subscription schemas', () => {
  it('accepts unique service types and notification weekdays', () => {
    expect(
      createChurchSubscriptionSchema.parse({
        churchId: 'c6000000-0000-4000-8000-000000000001',
        serviceTypes: ['mass', 'confession'],
        notificationWeekdays: ['sunday', 'wednesday'],
      }),
    ).toEqual(
      expect.objectContaining({
        serviceTypes: ['mass', 'confession'],
        notificationWeekdays: ['sunday', 'wednesday'],
      }),
    );
  });

  it('defaults omitted preferences to every service and every weekday', () => {
    expect(
      createChurchSubscriptionSchema.parse({
        churchId: 'c6000000-0000-4000-8000-000000000001',
      }),
    ).toEqual({
      churchId: 'c6000000-0000-4000-8000-000000000001',
      serviceTypes: ['mass', 'confession', 'adoration'],
      notificationWeekdays: [
        'sunday',
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
      ],
    });
  });

  it('rejects empty and duplicate subscription preferences', () => {
    expect(() =>
      createChurchSubscriptionSchema.parse({
        churchId: 'c6000000-0000-4000-8000-000000000001',
        serviceTypes: [],
        notificationWeekdays: ['sunday'],
      }),
    ).toThrow();
    expect(() =>
      createChurchSubscriptionSchema.parse({
        churchId: 'c6000000-0000-4000-8000-000000000001',
        serviceTypes: ['mass', 'mass'],
        notificationWeekdays: ['sunday'],
      }),
    ).toThrow('Service types must be unique.');
  });

  it('bounds upcoming occurrence windows', () => {
    expect(upcomingChurchServicesQuerySchema.parse({}).days).toBe(7);
    expect(() =>
      upcomingChurchServicesQuerySchema.parse({ days: 32 }),
    ).toThrow();
  });

  it('requires a Mass time but treats confession and adoration as optional', () => {
    expect(() =>
      reviewChurchScheduleSchema.parse({
        decision: 'verified',
        serviceTimes: [],
      }),
    ).toThrow();
    expect(() =>
      reviewChurchScheduleSchema.parse({
        decision: 'verified',
        serviceTimes: [
          {
            serviceType: 'confession',
            weekday: 'saturday',
            startTime: '16:00',
          },
          { serviceType: 'adoration', weekday: 'friday', startTime: '18:00' },
        ],
      }),
    ).toThrow(/At least one Mass time is required/);
    expect(
      reviewChurchScheduleSchema.parse({
        decision: 'verified',
        serviceTimes: [
          { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        ],
      }),
    ).toEqual(expect.objectContaining({ decision: 'verified' }));
    expect(
      reviewChurchScheduleSchema.parse({
        decision: 'verified',
        serviceTimes: [
          { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
          {
            serviceType: 'confession',
            weekday: 'saturday',
            startTime: '16:00',
          },
          { serviceType: 'adoration', weekday: 'friday', startTime: '18:00' },
        ],
      }),
    ).toEqual(expect.objectContaining({ decision: 'verified' }));
  });

  it('collapses repeated service, weekday, and start times', () => {
    const parsed = reviewChurchScheduleSchema.parse({
      decision: 'verified',
      serviceTimes: [
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        { serviceType: 'mass', weekday: 'sunday', startTime: '11:00' },
      ],
    });
    expect(parsed.decision === 'verified' && parsed.serviceTimes).toHaveLength(
      2,
    );
  });

  it('requires a reason when closing a church', () => {
    expect(() =>
      reviewChurchScheduleSchema.parse({ decision: 'closed' }),
    ).toThrow();
  });
});
