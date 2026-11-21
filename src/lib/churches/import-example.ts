import { churchServiceTypes, weekdayCodes } from '@/lib/schemas/church';

/** Example import file shown (and downloadable) in the admin Import JSON tab. */
export const churchImportExample = {
  churches: [
    {
      churchId: '00000000-0000-4000-8000-000000000000',
      label:
        'St. Example Parish, 1 Church St, Austin TX (optional note; not saved)',
      serviceTimes: [
        {
          serviceType: 'mass',
          weekday: 'sunday',
          startTime: '09:00',
          endTime: '10:00',
        },
        { serviceType: 'mass', weekday: 'sunday', startTime: '11:30' },
        {
          serviceType: 'confession',
          weekday: 'saturday',
          startTime: '15:00',
          endTime: '16:00',
        },
        {
          serviceType: 'adoration',
          weekday: 'friday',
          startTime: '18:00',
          endTime: '19:00',
        },
      ],
    },
    {
      church: {
        name: 'St. Mary Parish',
        addressLine1: '123 Main St',
        addressLine2: null,
        city: 'Providence',
        regionName: 'RI',
        postalCode: '02903',
        countryCode: 'US',
        timezone: 'America/New_York',
        latitude: 41.8236,
        longitude: -71.4222,
      },
      serviceTimes: [
        { serviceType: 'mass', weekday: 'saturday', startTime: '17:00' },
        { serviceType: 'mass', weekday: 'sunday', startTime: '08:00' },
      ],
    },
  ],
} as const;

export const churchImportNotes = [
  'Each entry needs serviceTimes with at least one "mass" time; confession and adoration are optional.',
  'Use "Find a church" above to pick the church from the directory; it adds an entry with the churchId filled in. label is an optional note for you and is never saved.',
  'A church is found by churchId when given; otherwise by church.name + church.addressLine1 + church.postalCode (case-insensitive).',
  'Found: its service times are replaced by the ones in the file (and any church fields you include are updated). Not found: it is created as a verified church, which needs name, addressLine1, city, countryCode, timezone, latitude and longitude.',
  `serviceType is one of: ${churchServiceTypes.join(', ')}. weekday is one of: ${weekdayCodes.join(', ')}.`,
  'Times use 24-hour HH:MM (for example 09:00, 17:30). endTime is optional.',
  'You always get a preview first; nothing is saved until you press Apply.',
] as const;
