import { GET as getLevels } from '../src/app/api/v1/levels/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, init?: ResponseInit) => {
    const headers = (init?.headers ?? {}) as Record<string, string>;
    return {
      status: 200,
      headers: {
        get: (name: string) =>
          Object.entries(headers).find(
            ([key]) => key.toLowerCase() === name.toLowerCase(),
          )?.[1] ?? null,
      },
      json: async () => ({ data }),
    };
  },
  errorResponse: (error: { name?: string; status?: number }) => ({
    status: error.name === 'ZodError' ? 422 : (error.status ?? 500),
    headers: { get: () => null },
    json: async () => ({ error: error.name }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);

function catalogClient() {
  const result = {
    data: [
      {
        level_number: 1,
        code: 'awakened',
        name: 'Awakened',
        description: 'Begins recognizing the battle.',
        minimum_total_xp: 0,
        icon_url: null,
        image_url: null,
        reward_type: 'title',
        reward_reference_id: null,
        is_active: true,
        created_at: '2026-09-21T00:00:00Z',
        translations: {
          es: {
            name: 'Despierto',
            description: 'Comienza a reconocer la batalla.',
          },
        },
      },
    ],
    error: null,
  };
  const builder: Record<string, unknown> = {};
  for (const method of ['select', 'eq', 'order']) {
    builder[method] = jest.fn(() => builder);
  }
  builder.then = (resolve: (value: typeof result) => unknown) =>
    Promise.resolve(result).then(resolve);
  const client = {
    schema: jest.fn(() => ({ from: jest.fn(() => builder) })),
    storage: {
      from: jest.fn(() => ({
        getPublicUrl: jest.fn(() => ({ data: { publicUrl: '' } })),
      })),
    },
  };
  return client;
}

describe('localized catalog routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns explicit Spanish level fields without translation storage', async () => {
    mockedRequireUser.mockResolvedValue({
      supabase: catalogClient(),
      userId: 'user-id',
      claims: {},
      authMode: 'bearer',
    } as never);

    const response = await getLevels({
      url: 'http://localhost/api/v1/levels?language=es',
    } as Request);
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get('Content-Language')).toBe('es');
    expect(response.headers.get('Cache-Control')).toBe('private, no-store');
    expect(body.data[0]).toMatchObject({
      code: 'awakened',
      name: 'Despierto',
      description: 'Comienza a reconocer la batalla.',
    });
    expect(body.data[0]).not.toHaveProperty('translations');
  });

  it('rejects unsupported explicit languages', async () => {
    mockedRequireUser.mockResolvedValue({
      supabase: catalogClient(),
      userId: 'user-id',
      claims: {},
      authMode: 'bearer',
    } as never);

    const response = await getLevels({
      url: 'http://localhost/api/v1/levels?language=fr',
    } as Request);

    expect(response.status).toBe(422);
  });
});
