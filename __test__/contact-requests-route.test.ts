import { POST } from '../src/app/api/v1/contact-requests/route';
import { createAdminClient } from '../src/lib/supabase/admin';

jest.mock('../src/lib/supabase/admin', () => ({
  createAdminClient: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  errorResponse: jest.fn((error: { name?: string }) => ({
    status: error.name === 'ZodError' ? 422 : 500,
    json: async () => ({ error: error.name }),
  })),
}));

const mockedCreateAdminClient = jest.mocked(createAdminClient);

describe('POST /api/v1/contact-requests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('stores a fixed-subject contact request without returning contact details', async () => {
    const query: Record<string, jest.Mock> = {};
    query.insert = jest.fn().mockReturnValue(query);
    query.select = jest.fn().mockReturnValue(query);
    query.single = jest.fn().mockResolvedValue({
      data: {
        id: 'c9000000-0000-4000-8000-000000000001',
        created_at: '2026-08-22T12:00:00.000Z',
      },
      error: null,
    });
    const from = jest.fn(() => query);
    mockedCreateAdminClient.mockReturnValue({
      schema: jest.fn(() => ({ from })),
    } as never);

    const response = await POST({
      headers: {
        get: (name: string) =>
          name === 'content-type' ? 'application/json' : null,
      },
      json: async () => ({
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        subject: 'Billing & Payments',
        message: 'Please send my receipt.',
      }),
    } as unknown as Request);

    expect(query.insert).toHaveBeenCalledWith({
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      subject: 'Billing & Payments',
      other_subject: null,
      message: 'Please send my receipt.',
    });
    expect(await response.json()).toEqual({
      data: {
        id: 'c9000000-0000-4000-8000-000000000001',
        createdAt: '2026-08-22T12:00:00.000Z',
      },
    });
  });

  it('requires an otherSubject when Other is selected', async () => {
    const response = await POST({
      headers: { get: () => 'application/json' },
      json: async () => ({
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        subject: 'Other',
        message: 'A new request.',
      }),
    } as unknown as Request);

    expect(createAdminClient).not.toHaveBeenCalled();
    expect(response.status).toBe(422);
  });
});
