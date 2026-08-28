import {
  citySearchQuerySchema,
  countrySearchQuerySchema,
} from '../src/lib/schemas/locations';

describe('location search API schemas', () => {
  it('supports listing or filtering countries with bounded pagination', () => {
    expect(countrySearchQuerySchema.parse({})).toEqual({
      limit: 20,
      offset: 0,
    });
    expect(
      countrySearchQuerySchema.parse({ q: '  united  ', limit: '10' }),
    ).toEqual({ q: 'united', limit: 10, offset: 0 });
  });

  it('requires a country and at least two city-search characters', () => {
    expect(
      citySearchQuerySchema.parse({ countryCode: 'us', q: '  aus ' }),
    ).toEqual({ countryCode: 'US', q: 'aus', limit: 20, offset: 0 });
    expect(() =>
      citySearchQuerySchema.parse({ countryCode: 'US', q: 'a' }),
    ).toThrow();
    expect(() => citySearchQuerySchema.parse({ q: 'Austin' })).toThrow();
  });
});
