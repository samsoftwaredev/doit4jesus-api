import { countrySearchQuerySchema } from '../src/lib/schemas/locations';

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
});
