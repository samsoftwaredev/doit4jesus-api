import {
  adminUserDeletionPreviewQuerySchema,
  adminUserSearchQuerySchema,
  userSearchQuerySchema,
} from '@/lib/schemas/users';

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

describe('administrator account-deletion schemas', () => {
  it('accepts bounded email/UUID searches and preview pages', () => {
    expect(adminUserSearchQuerySchema.parse({ q: 'member' })).toEqual({
      q: 'member',
      limit: 20,
    });
    expect(
      adminUserDeletionPreviewQuerySchema.parse({
        section: 'prayer',
        offset: '25',
      }),
    ).toEqual({ section: 'prayer', limit: 50, offset: 25 });
    expect(() => adminUserSearchQuerySchema.parse({ q: 'x' })).toThrow();
    expect(() =>
      adminUserDeletionPreviewQuerySchema.parse({ section: 'email' }),
    ).toThrow();
  });
});
