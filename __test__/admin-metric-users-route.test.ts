import { GET } from '../src/app/api/v1/admin/app-metrics/users/route';
import { errorResponse } from '../src/lib/api/response';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const mockedErrorResponse = jest.mocked(errorResponse);
const requestFor = (query: string) =>
  ({
    url: `http://localhost/api/v1/admin/app-metrics/users?${query}`,
  }) as Request;

function mockRpc(result: { data: unknown; error: unknown }) {
  const rpc = jest.fn().mockResolvedValue(result);
  mockedRequireAdmin.mockResolvedValue({
    supabase: { schema: jest.fn(() => ({ rpc })) },
  } as never);
  return rpc;
}

describe('GET /api/v1/admin/app-metrics/users', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns the users behind a metric after administrator authorization', async () => {
    const payload = { total: 1, users: [{ id: 'u1', email: 'a@b.c' }] };
    const rpc = mockRpc({ data: payload, error: null });

    const response = await GET(
      requestFor('metric=retention_d7&filter=no&limit=20&offset=40'),
    );

    expect(mockedRequireAdmin).toHaveBeenCalledTimes(1);
    expect(rpc).toHaveBeenCalledWith('get_admin_metric_users', {
      p_metric: 'retention_d7',
      p_filter: 'no',
      p_limit: 20,
      p_offset: 40,
    });
    expect(response).toMatchObject({});
    expect((response as unknown as Response).headers.get('Cache-Control')).toBe(
      'no-store',
    );
    expect(await (response as unknown as Response).json()).toEqual({
      data: payload,
    });
  });

  it('applies defaults', async () => {
    const rpc = mockRpc({ data: {}, error: null });
    await GET(requestFor('metric=dau'));
    expect(rpc).toHaveBeenCalledWith('get_admin_metric_users', {
      p_metric: 'dau',
      p_filter: 'all',
      p_limit: 50,
      p_offset: 0,
    });
  });

  it('rejects an unknown metric before touching the database', async () => {
    await GET(requestFor('metric=hacked'));
    expect(mockedRequireAdmin).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledTimes(1);
  });

  it('rejects an oversized page', async () => {
    await GET(requestFor('metric=dau&limit=500'));
    expect(mockedRequireAdmin).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledTimes(1);
  });

  it('reports database failures through the error response', async () => {
    mockRpc({ data: null, error: { code: 'XX000', message: 'boom' } });
    await GET(requestFor('metric=dau'));
    expect(mockedErrorResponse).toHaveBeenCalledTimes(1);
  });
});
