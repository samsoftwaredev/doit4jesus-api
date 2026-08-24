import { GET } from '../src/app/api/v1/admin/contact-requests/route';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, _init?: unknown, meta?: unknown) => ({
    status: 200,
    json: async () => ({ data, meta }),
  }),
  errorResponse: jest.fn(),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);

function createFixture(rows: unknown[]) {
  const query: Record<
    string,
    | jest.Mock
    | ((...args: unknown[]) => Promise<{ data: unknown[]; error: null }>)
  > = {};
  for (const method of ['select', 'order', 'eq', 'gte', 'lt', 'ilike']) {
    query[method] = jest.fn(() => query);
  }
  query.range = jest.fn().mockResolvedValue({ data: rows, error: null });

  const from = jest.fn(() => query);
  mockedRequireAdmin.mockResolvedValue({
    supabase: { schema: jest.fn(() => ({ from })) },
  } as never);

  return { query, from };
}

describe('GET /api/v1/admin/contact-requests', () => {
  beforeEach(() => jest.clearAllMocks());

  it('requires an admin and filters a paginated contact-request queue', async () => {
    const firstRow = {
      id: 'c9000000-0000-4000-8000-000000000001',
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      subject: 'Billing & Payments',
      other_subject: null,
      message: 'Please send my receipt.',
      status: 'inprogress',
      created_at: '2026-08-22T12:00:00.000Z',
    };
    const fixture = createFixture([
      firstRow,
      { ...firstRow, id: 'c9000000-0000-4000-8000-000000000002' },
    ]);

    const response = await GET({
      url: 'http://localhost/api/v1/admin/contact-requests?status=inprogress&created_at=2026-08-22&email=ADA%40example.com&name=Ada&subject=Billing%20%26%20Payments&limit=1&offset=2',
    } as Request);

    expect(mockedRequireAdmin).toHaveBeenCalledTimes(1);
    expect(fixture.from).toHaveBeenCalledWith('contact_requests');
    expect(fixture.query.eq).toHaveBeenCalledWith('status', 'inprogress');
    expect(fixture.query.gte).toHaveBeenCalledWith(
      'created_at',
      '2026-08-22T00:00:00.000Z',
    );
    expect(fixture.query.lt).toHaveBeenCalledWith(
      'created_at',
      '2026-08-23T00:00:00.000Z',
    );
    expect(fixture.query.ilike).toHaveBeenCalledWith(
      'email',
      'ADA@example.com',
    );
    expect(fixture.query.ilike).toHaveBeenCalledWith('name', '%Ada%');
    expect(fixture.query.eq).toHaveBeenCalledWith(
      'subject',
      'Billing & Payments',
    );
    expect(fixture.query.range).toHaveBeenCalledWith(2, 3);
    expect(await response.json()).toEqual({
      data: [firstRow],
      meta: { limit: 1, offset: 2, hasMore: true, nextOffset: 3 },
    });
  });
});
