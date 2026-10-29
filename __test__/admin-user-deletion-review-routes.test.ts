import { GET as preview } from '../src/app/api/v1/admin/users/[userId]/deletion-preview/route';
import { GET as search } from '../src/app/api/v1/admin/users/route';
import { errorResponse } from '../src/lib/api/response';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit, meta?: unknown) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data, meta }),
  }),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const mockedErrorResponse = jest.mocked(errorResponse);
const USER_ID = '22222222-2222-4222-8222-222222222222';

describe('administrator user-deletion review routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('searches using the protected administrator RPC and does not cache results', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: [
        {
          id: USER_ID,
          email: 'member@example.com',
          status: 'active',
          created_at: '2026-10-01T00:00:00Z',
          display_name: 'Member',
          username: 'member',
          is_admin: false,
        },
      ],
      error: null,
    });
    mockedRequireAdmin.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await search({
      url: 'http://localhost/api/v1/admin/users?q=member',
    } as Request);

    expect(rpc).toHaveBeenCalledWith('search_admin_users', {
      p_query: 'member',
      p_limit: 20,
    });
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(await response.json()).toEqual(
      expect.objectContaining({
        data: [
          expect.objectContaining({
            createdAt: '2026-10-01T00:00:00Z',
            isProtectedAdmin: false,
          }),
        ],
      }),
    );
  });

  it('loads a paginated preview and returns matching pagination metadata', async () => {
    const rpc = jest
      .fn()
      .mockResolvedValueOnce({
        data: { recordCount: 26, records: [] },
        error: null,
      })
      .mockResolvedValueOnce({
        data: [{ terms_version: '2026-10-28' }],
        error: null,
      });
    const or = jest.fn().mockResolvedValue({ data: [], error: null });
    const select = jest.fn(() => ({ or }));
    mockedRequireAdmin.mockResolvedValue({
      supabase: {
        schema: jest.fn((name: string) =>
          name === 'api' ? { rpc } : { from: jest.fn(() => ({ select })) },
        ),
      },
    } as never);

    const response = await preview(
      {
        url: `http://localhost/api/v1/admin/users/${USER_ID}/deletion-preview?section=prayer&limit=25`,
      } as Request,
      { params: Promise.resolve({ userId: USER_ID }) },
    );

    expect(rpc).toHaveBeenCalledWith('get_admin_user_deletion_preview', {
      p_user_id: USER_ID,
      p_section: 'prayer',
      p_limit: 25,
      p_offset: 0,
    });
    expect(rpc).toHaveBeenCalledWith('get_admin_user_legal_acceptances', {
      p_user_id: USER_ID,
    });
    expect(await response.json()).toEqual(
      expect.objectContaining({
        data: expect.objectContaining({
          legalAcceptances: [{ terms_version: '2026-10-28' }],
          userBlocks: [],
          safetyReports: [],
        }),
        meta: { limit: 25, offset: 0, hasMore: true, nextOffset: 25 },
      }),
    );
  });

  it('rejects invalid searches before authorization', async () => {
    await search({ url: 'http://localhost/api/v1/admin/users?q=x' } as Request);
    expect(mockedRequireAdmin).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'ZodError' }),
      expect.anything(),
    );
  });
});
