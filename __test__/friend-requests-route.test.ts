import { GET } from '../src/app/api/v1/me/friend-requests/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  created: jest.fn(),
  errorResponse: jest.fn(),
  ok: (data: unknown, _init: unknown, meta?: unknown) => ({
    json: async () => (meta ? { data, meta } : { data }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);

describe('GET /api/v1/me/friend-requests', () => {
  it('normalizes incoming and outgoing requests around the other user', async () => {
    const senderId = '11111111-1111-4111-8111-111111111111';
    const recipientId = '22222222-2222-4222-822222222222';
    const rpc = jest.fn().mockResolvedValue({
      data: [
        {
          id: '33333333-3333-4333-8333-333333333333',
          status: 'pending',
          direction: 'incoming',
          created_at: '2026-08-17T00:00:00.000Z',
          responded_at: null,
          cancelled_at: null,
          user_id: senderId,
          display_name: 'Request Sender',
          username: 'sender',
          avatar_url: null,
          title: null,
        },
        {
          id: '44444444-4444-4444-8444-444444444444',
          status: 'pending',
          direction: 'outgoing',
          created_at: '2026-08-16T00:00:00.000Z',
          responded_at: null,
          cancelled_at: null,
          user_id: recipientId,
          display_name: 'Request Recipient',
          username: 'recipient',
          avatar_url: null,
          title: null,
        },
      ],
      error: null,
    });
    const supabase = {
      schema: jest.fn(() => ({ rpc })),
    };
    mockedRequireUser.mockResolvedValue({ supabase } as never);

    const response = await GET({
      url: 'http://localhost:3000/api/v1/me/friend-requests?direction=all&status=pending',
    } as Request);
    const body = await response.json();

    expect(body).toMatchObject({
      data: [
        {
          direction: 'incoming',
          user: { id: senderId, displayName: 'Request Sender' },
        },
        {
          direction: 'outgoing',
          user: { id: recipientId, displayName: 'Request Recipient' },
        },
      ],
      meta: { limit: 20, offset: 0, hasMore: false, nextOffset: null },
    });
    expect(rpc).toHaveBeenCalledWith('list_current_user_friend_requests', {
      p_direction: 'all',
      p_status: 'pending',
      p_limit: 21,
      p_offset: 0,
    });
  });
});
