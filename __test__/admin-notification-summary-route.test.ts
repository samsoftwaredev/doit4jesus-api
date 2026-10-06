import { GET } from '../src/app/api/v1/admin/notification-summary/route';
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

function countQuery(
  result: { count: number; error: null },
  method: 'eq' | 'in',
) {
  const query = { [method]: jest.fn().mockResolvedValue(result) };
  return { select: jest.fn(() => query), query };
}

function previewQuery(
  result: { data: unknown[]; error: null },
  method: 'eq' | 'in',
) {
  const limit = jest.fn().mockResolvedValue(result);
  const finalOrder = { limit };
  const secondOrder = { order: jest.fn(() => finalOrder) };
  const firstOrder = { order: jest.fn(() => secondOrder) };
  const query = { [method]: jest.fn(() => firstOrder) };
  return {
    select: jest.fn(() => query),
    query,
    firstOrder,
    secondOrder,
    limit,
  };
}

describe('GET /api/v1/admin/notification-summary', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns exact actionable counts and the three newest previews per queue', async () => {
    const contactCount = countQuery({ count: 4, error: null }, 'in');
    const prayerCount = countQuery({ count: 2, error: null }, 'eq');
    const churchCount = countQuery({ count: 1, error: null }, 'eq');
    const contactPreview = previewQuery(
      {
        data: [
          {
            id: 'c9000000-0000-4000-8000-000000000001',
            name: 'Ada Lovelace',
            subject: 'Billing & Payments',
            created_at: '2026-10-05T10:00:00.000Z',
          },
        ],
        error: null,
      },
      'in',
    );
    const prayerPreview = previewQuery(
      {
        data: [
          {
            id: 'd9000000-0000-4000-8000-000000000001',
            title: 'For healing',
            created_at: '2026-10-05T09:00:00.000Z',
          },
        ],
        error: null,
      },
      'eq',
    );
    const churchPreview = previewQuery(
      {
        data: [
          {
            id: 'c8000000-0000-4000-8000-000000000001',
            request_type: 'schedule_update',
            church_id: 'c6000000-0000-4000-8000-000000000001',
            created_at: '2026-10-05T08:00:00.000Z',
          },
        ],
        error: null,
      },
      'eq',
    );
    const from = jest
      .fn()
      .mockReturnValueOnce(contactCount)
      .mockReturnValueOnce(prayerCount)
      .mockReturnValueOnce(churchCount)
      .mockReturnValueOnce(contactPreview)
      .mockReturnValueOnce(prayerPreview)
      .mockReturnValueOnce(churchPreview);
    const schema = jest.fn(() => ({ from }));
    mockedRequireAdmin.mockResolvedValue({ supabase: { schema } } as never);

    const response = await GET({
      url: 'http://localhost/api/v1/admin/notification-summary',
    } as Request);

    expect(mockedRequireAdmin).toHaveBeenCalledTimes(1);
    expect(contactCount.select).toHaveBeenCalledWith('*', {
      count: 'exact',
      head: true,
    });
    expect(contactCount.query.in).toHaveBeenCalledWith('status', [
      'todo',
      'inprogress',
    ]);
    expect(prayerCount.query.eq).toHaveBeenCalledWith('status', 'pending');
    expect(churchCount.query.eq).toHaveBeenCalledWith('status', 'pending');
    expect(contactPreview.limit).toHaveBeenCalledWith(3);
    expect(prayerPreview.limit).toHaveBeenCalledWith(3);
    expect(churchPreview.limit).toHaveBeenCalledWith(3);
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(await response.json()).toEqual({
      data: {
        total: 7,
        contacts: {
          count: 4,
          items: [
            {
              id: 'c9000000-0000-4000-8000-000000000001',
              name: 'Ada Lovelace',
              subject: 'Billing & Payments',
              createdAt: '2026-10-05T10:00:00.000Z',
            },
          ],
        },
        prayerIntentions: {
          count: 2,
          items: [
            {
              id: 'd9000000-0000-4000-8000-000000000001',
              title: 'For healing',
              createdAt: '2026-10-05T09:00:00.000Z',
            },
          ],
        },
        churchChangeRequests: {
          count: 1,
          items: [
            {
              id: 'c8000000-0000-4000-8000-000000000001',
              requestType: 'schedule_update',
              churchId: 'c6000000-0000-4000-8000-000000000001',
              createdAt: '2026-10-05T08:00:00.000Z',
            },
          ],
        },
      },
    });
  });
});
