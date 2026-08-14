import { userSearchQuerySchema } from '@/lib/schemas/users';

describe('user search API schema', () => {
  it('requires a four-character username search and pages it safely', () => {
    expect(userSearchQuerySchema.parse({ q: 'JoHN' })).toEqual({
      q: 'JoHN',
      limit: 20,
      offset: 0,
    });
    expect(() => userSearchQuerySchema.parse({ q: 'abc' })).toThrow();
    expect(() => userSearchQuerySchema.parse({ q: 'name%' })).toThrow();
  });
});
