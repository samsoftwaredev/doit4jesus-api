import {
  localizeCatalogRow,
  normalizeCatalogLanguage,
  readCatalogLanguage,
  resolveCatalogLanguage,
} from '../src/lib/catalog/localization';

describe('catalog localization', () => {
  it('normalizes Spanish and English profile language tags', () => {
    expect(normalizeCatalogLanguage('es-MX')).toBe('es');
    expect(normalizeCatalogLanguage('EN-us')).toBe('en');
    expect(normalizeCatalogLanguage('fr')).toBe('en');
    expect(normalizeCatalogLanguage(null)).toBe('en');
  });

  it('validates explicit language overrides', () => {
    expect(
      readCatalogLanguage(new URL('https://example.test?language=es')),
    ).toBe('es');
    expect(() =>
      readCatalogLanguage(new URL('https://example.test?language=fr')),
    ).toThrow();
  });

  it('uses translated fields, deep-merges rules, and hides translations', () => {
    const localized = localizeCatalogRow(
      {
        code: 'SHIELD',
        name: 'Shield',
        description: 'English description',
        rules: { virtue: 'faith', description: 'English rule' },
        translations: {
          es: {
            name: 'Escudo',
            rules: { description: 'Regla en español' },
          },
        },
      },
      'es',
    );

    expect(localized).toEqual({
      code: 'SHIELD',
      name: 'Escudo',
      description: 'English description',
      rules: { virtue: 'faith', description: 'Regla en español' },
    });
    expect(localized).not.toHaveProperty('translations');
  });

  it('prefers an explicit language and otherwise uses the profile', async () => {
    const maybeSingle = jest.fn().mockResolvedValue({
      data: { preferred_language: 'es-MX' },
      error: null,
    });
    const eq = jest.fn(() => ({ maybeSingle }));
    const select = jest.fn(() => ({ eq }));
    const from = jest.fn(() => ({ select }));
    const supabase = { schema: jest.fn(() => ({ from })) };

    await expect(
      resolveCatalogLanguage(supabase as never, 'user-id', 'en'),
    ).resolves.toBe('en');
    expect(from).not.toHaveBeenCalled();

    await expect(
      resolveCatalogLanguage(supabase as never, 'user-id'),
    ).resolves.toBe('es');
    expect(eq).toHaveBeenCalledWith('user_id', 'user-id');

    maybeSingle.mockResolvedValueOnce({ data: null, error: null });
    await expect(
      resolveCatalogLanguage(supabase as never, 'missing-user'),
    ).resolves.toBe('en');
  });
});
