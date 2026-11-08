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

  it('requires a complete schedule when verifying a church', () => {
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
            serviceType: 'mass',
            weekday: 'sunday',
            startTime: '09:00',
          },
        ],
      }),
    ).toThrow(/Mass, confession, and adoration/);
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
          {
            serviceType: 'adoration',
            weekday: 'friday',
            startTime: '18:00',
          },
        ],
      }),
    ).toEqual(expect.objectContaining({ decision: 'verified' }));
  });

  it('requires a reason when closing a church', () => {
    expect(() =>
      reviewChurchScheduleSchema.parse({ decision: 'closed' }),
    ).toThrow();
  });
});
