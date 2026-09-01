import { getProfileSetup } from '../src/lib/profiles/setup';
import { updateProfileSchema } from '../src/lib/schemas/profile';

describe('required profile setup', () => {
  it('derives completion from required values instead of the audit timestamp', () => {
    expect(
      getProfileSetup({
        displayName: 'Samuel Ruiz',
        gender: 'male',
        countryCode: 'US',
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
        completedAt: '2026-08-28T12:00:00.000Z',
      }),
    ).toEqual({
      complete: false,
      missingFields: ['displayName', 'gender', 'country'],
      nextStep: 'name',
      completedAt: '2026-08-28T12:00:00.000Z',
    });
  });

  it('trims and collapses display-name whitespace without splitting the name', () => {
    expect(
      updateProfileSchema.parse({ displayName: '  Juan   Carlos Ruiz  ' }),
    ).toEqual({ displayName: 'Juan Carlos Ruiz' });
    expect(() => updateProfileSchema.parse({ displayName: '   ' })).toThrow();
  });

  it('accepts the supported GB subdivision country codes', () => {
    expect(updateProfileSchema.parse({ countryCode: 'gb-sct' })).toEqual({
      countryCode: 'GB-SCT',
    });
  });
});
