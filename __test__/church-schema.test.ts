import {
  churchSearchQuerySchema,
  createChurchChangeRequestSchema,
} from '@/lib/schemas/church';

describe('church directory schemas', () => {
  it.each([
    [{ countryCode: 'us' }, { countryCode: 'US' }],
    [{ city: 'Austin' }, { city: 'Austin' }],
    [{ diocese: 'Diocese of Austin' }, { diocese: 'Diocese of Austin' }],
    [
      {
        countryCode: 'us',
        city: 'Austin',
        diocese: 'Diocese of Austin',
      },
      {
        countryCode: 'US',
        city: 'Austin',
        diocese: 'Diocese of Austin',
      },
    ],
  ])('accepts one or more church search filters', (input, expected) => {
    expect(churchSearchQuerySchema.parse(input)).toEqual(
      expect.objectContaining(expected),
    );
  });

  it('requires at least one church search filter', () => {
    expect(() => churchSearchQuerySchema.parse({})).toThrow(
      'At least one church search filter is required.',
    );
  });

  it('accepts postal, radius, diocese ID, and name or address searches', () => {
    expect(
      churchSearchQuerySchema.parse({
        postalCode: '78701',
        radiusMiles: '15',
        dioceseId: 'c5000000-0000-4000-8000-000000000001',
        q: 'St. Mary',
      }),
    ).toEqual(
      expect.objectContaining({
        postalCode: '78701',
        radiusMiles: 15,
        q: 'St. Mary',
      }),
    );
  });

  it('allows a global church name or address search', () => {
    expect(churchSearchQuerySchema.parse({ q: 'Guadalupe' }).q).toBe(
      'Guadalupe',
    );
  });

  it('requires coordinates when proposing a new church', () => {
    expect(() =>
      createChurchChangeRequestSchema.parse({
        requestType: 'createChurch',
        church: {
          name: 'Example Catholic Church',
          addressLine1: '123 Example Street',
          city: 'Austin',
          countryCode: 'US',
          timezone: 'America/Chicago',
          latitude: 30.2672,
        },
        serviceTimes: [
          {
            serviceType: 'mass',
            weekday: 'sunday',
            startTime: '09:00',
          },
        ],
      }),
    ).toThrow();
  });
});
