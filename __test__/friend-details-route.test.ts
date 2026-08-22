import { GET } from '../src/app/api/v1/me/friends/[friendId]/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  noContent: jest.fn(),
  ok: (data: unknown) => ({
    json: async () => ({ data }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);

describe('GET /api/v1/me/friends/{friendId}', () => {
  it('requests the Rosary streak only when include=rosaryStreak is supplied', async () => {
    const friendId = '11111111-1111-4111-8111-111111111111';
    const rpc = jest
      .fn()
      .mockResolvedValue({ data: { friend: { id: friendId } }, error: null });
    const supabase = {
      schema: jest.fn(() => ({ rpc })),
    };
    mockedRequireUser.mockResolvedValue({ supabase } as never);

    const response = await GET(
      {
        url: `http://localhost:3000/api/v1/me/friends/${friendId}?include=rosaryStreak`,
      } as Request,
      { params: Promise.resolve({ friendId }) },
    );

    expect(await response.json()).toEqual({
      data: { friend: { id: friendId } },
    });
    expect(rpc).toHaveBeenCalledWith('get_current_user_friend_details', {
      p_friend_id: friendId,
      p_include_rosary_streak: true,
    });
  });
});
