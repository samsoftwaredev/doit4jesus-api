import { PATCH as reviewReport } from '../src/app/api/v1/admin/reports/[reportId]/route';
import {
  POST as block,
  DELETE as unblock,
} from '../src/app/api/v1/me/blocks/[userId]/route';
import { POST as submitReport } from '../src/app/api/v1/me/reports/route';
import { requireAdmin } from '../src/lib/auth/require-admin';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  created: (data: unknown) => ({ status: 201, data }),
  ok: (data: unknown) => ({ status: 200, data }),
  noContent: () => ({ status: 204 }),
  errorResponse: (error: unknown) => {
    throw error;
  },
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedRequireAdmin = jest.mocked(requireAdmin);
const userId = '11111111-1111-4111-8111-111111111111';
const targetId = '22222222-2222-4222-8222-222222222222';
const reportId = '33333333-3333-4333-8333-333333333333';

function jsonRequest(url: string, body: unknown) {
  return {
    url,
    headers: {
      get: (name: string) =>
        name.toLowerCase() === 'content-type' ? 'application/json' : null,
    },
    json: async () => body,
  } as unknown as Request;
}

describe('community safety routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('submits a categorized event report with the authenticated reporter ID', async () => {
    const single = jest.fn().mockResolvedValue({
      data: {
        id: reportId,
        status: 'open',
        created_at: '2026-10-28T12:00:00Z',
      },
      error: null,
    });
    const select = jest.fn(() => ({ single }));
    const insert = jest.fn(() => ({ select }));
    mockedRequireUser.mockResolvedValue({
      userId,
      supabase: {
        schema: jest.fn(() => ({ from: jest.fn(() => ({ insert })) })),
      },
    } as never);

    const response = await submitReport(
      jsonRequest('http://localhost/api/v1/me/reports', {
        targetType: 'event',
        targetId,
        reason: 'privacy',
        details: 'The address contains private information.',
      }),
    );

    expect(response.status).toBe(201);
    expect(insert).toHaveBeenCalledWith(
      expect.objectContaining({
        reporter_id: userId,
        event_id: targetId,
        reason: 'privacy',
      }),
    );
  });

  it('blocks idempotently and supports unblocking', async () => {
    const single = jest.fn().mockResolvedValue({
      data: { blocked_user_id: targetId, created_at: '2026-10-28T12:00:00Z' },
      error: null,
    });
    const select = jest.fn(() => ({ single }));
    const upsert = jest.fn(() => ({ select }));
    const eqSecond = jest.fn().mockResolvedValue({ error: null });
    const eqFirst = jest.fn(() => ({ eq: eqSecond }));
    const deleteRecord = jest.fn(() => ({ eq: eqFirst }));
    mockedRequireUser.mockResolvedValue({
      userId,
      supabase: {
        schema: jest.fn(() => ({
          from: jest.fn(() => ({ upsert, delete: deleteRecord })),
        })),
      },
    } as never);

    const blockResponse = await block({ url: 'http://localhost' } as Request, {
      params: Promise.resolve({ userId: targetId }),
    });
    const unblockResponse = await unblock(
      { url: 'http://localhost' } as Request,
      {
        params: Promise.resolve({ userId: targetId }),
      },
    );

    expect(blockResponse.status).toBe(201);
    expect(upsert).toHaveBeenCalledWith(
      { blocker_id: userId, blocked_user_id: targetId },
      { onConflict: 'blocker_id,blocked_user_id' },
    );
    expect(unblockResponse.status).toBe(204);
    expect(eqFirst).toHaveBeenCalledWith('blocker_id', userId);
    expect(eqSecond).toHaveBeenCalledWith('blocked_user_id', targetId);
  });

  it('records an administrator resolution and review timestamp', async () => {
    const single = jest.fn().mockResolvedValue({
      data: { id: reportId, status: 'resolved' },
      error: null,
    });
    const select = jest.fn(() => ({ single }));
    const eq = jest.fn(() => ({ select }));
    const update = jest.fn(() => ({ eq }));
    mockedRequireAdmin.mockResolvedValue({
      userId,
      supabase: {
        schema: jest.fn(() => ({ from: jest.fn(() => ({ update })) })),
      },
    } as never);

    const response = await reviewReport(
      jsonRequest('http://localhost', {
        status: 'resolved',
        adminNotes: 'Removed content.',
      }),
      { params: Promise.resolve({ reportId }) },
    );
    expect(response.status).toBe(200);
    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'resolved',
        reviewed_by: userId,
        admin_notes: 'Removed content.',
      }),
    );
  });
});
