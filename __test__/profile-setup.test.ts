import { getProfileSetup } from '../src/lib/profiles/setup';
import { updateProfileSchema } from '../src/lib/schemas/profile';

describe('required profile setup', () => {
  it('derives completion from required values instead of the audit timestamp', () => {
    expect(
      getProfileSetup({
        displayName: 'Samuel Ruiz',
        gender: 'male',
        countryCode: 'US',
        cityId: 'e0000000-0000-4000-8000-000000000001',
        completedAt: null,
      }),
    ).toEqual({
      complete: true,
      missingFields: [],
      nextStep: null,
      completedAt: null,
    });
  });

  it('reports all missing values and the earliest incomplete step', () => {
    expect(
      getProfileSetup({
        displayName: '   ',
        gender: null,
        countryCode: null,
        cityId: null,
        completedAt: '2026-08-28T12:00:00.000Z',
      }),
    ).toEqual({
      complete: false,
      missingFields: ['displayName', 'gender', 'country', 'city'],
      nextStep: 'name',
      completedAt: '2026-08-28T12:00:00.000Z',
    });
  });

  it('resumes at city when it is the first missing required value', () => {
    expect(
      getProfileSetup({
        displayName: 'Samuel Ruiz',
        gender: 'male',
        countryCode: 'US',
        cityId: null,
        completedAt: null,
      }),
    ).toEqual(
      expect.objectContaining({
        complete: false,
        missingFields: ['city'],
        nextStep: 'city',
      }),
    );
  });

  it('trims and collapses display-name whitespace without splitting the name', () => {
    expect(
      updateProfileSchema.parse({ displayName: '  Juan   Carlos Ruiz  ' }),
    ).toEqual({ displayName: 'Juan Carlos Ruiz' });
    expect(() => updateProfileSchema.parse({ displayName: '   ' })).toThrow();
  });
});
