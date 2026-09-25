import { DELETE } from '../src/app/api/v1/admin/users/[userId]/route';
import { errorResponse } from '../src/lib/api/response';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));

jest.mock('../src/lib/api/response', () => ({
  noContent: () => ({ status: 204 }),
  errorResponse: jest.fn(),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const mockedErrorResponse = jest.mocked(errorResponse);
const USER_ID = '22222222-2222-4222-8222-222222222222';

describe('DELETE /api/v1/admin/users/{userId}', () => {
  beforeEach(() => jest.clearAllMocks());

  it('permanently deletes the target account for an administrator', async () => {
    const rpc = jest.fn().mockResolvedValue({ data: null, error: null });
    mockedRequireAdmin.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await DELETE({} as Request, {
      params: Promise.resolve({ userId: USER_ID }),
    });

    expect(rpc).toHaveBeenCalledWith('delete_user_account', {
      p_user_id: USER_ID,
    });
    expect(response.status).toBe(204);
  });

  it('rejects an invalid target user ID before authorizing the request', async () => {
    await DELETE({} as Request, {
      params: Promise.resolve({ userId: 'not-a-uuid' }),
    });

    expect(mockedRequireAdmin).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'ZodError' }),
      expect.anything(),
    );
  });
});
