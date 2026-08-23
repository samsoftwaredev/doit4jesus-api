import {
  DELETE,
  PATCH,
} from '../src/app/api/v1/admin/examination-of-conscience/[questionId]/route';
import {
  POST,
  GET as getAdminQuestions,
} from '../src/app/api/v1/admin/examination-of-conscience/route';
import { GET as getDailyQuestion } from '../src/app/api/v1/examination-of-conscience/route';
import { requireAdmin } from '../src/lib/auth/require-admin';
import { createAdminClient } from '../src/lib/supabase/admin';

jest.mock('../src/lib/supabase/admin', () => ({
  createAdminClient: jest.fn(),
}));
jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, _init?: unknown, meta?: unknown) => ({
    status: 200,
    json: async () => (meta ? { data, meta } : { data }),
  }),
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  noContent: () => ({ status: 204 }),
  errorResponse: (error: { name?: string; status?: number }) => ({
    status: error.name === 'ZodError' ? 422 : (error.status ?? 500),
    json: async () => ({ error: error.name }),
  }),
}));

const mockedCreateAdminClient = jest.mocked(createAdminClient);
const mockedRequireAdmin = jest.mocked(requireAdmin);

const QUESTION_ID = 'e1000000-0000-4000-8000-000000000001';
const question = {
  id: QUESTION_ID,
  category: 'single' as const,
  title: 'Faith',
  commandment: 1,
  severity: 'mortal' as const,
  question: 'Have I denied the Catholic faith?',
  description: 'A grave matter.',
  counsels: ['Return through Confession.'],
  prevention: ['Pray daily.'],
  saints: ['St. Augustine'],
  is_active: true,
  created_at: '2026-08-22T00:00:00.000Z',
  updated_at: '2026-08-22T00:00:00.000Z',
};

type QueryResult = { data: unknown; error: null };

function query(result: QueryResult) {
  const builder: Record<
    string,
    jest.Mock | ((...args: unknown[]) => Promise<QueryResult>)
  > = {};
  for (const method of [
    'select',
    'eq',
    'order',
    'range',
    'insert',
    'update',
    'delete',
  ]) {
    builder[method] = jest.fn(() => builder);
  }
  builder.single = jest.fn().mockResolvedValue(result);
  builder.maybeSingle = jest.fn().mockResolvedValue(result);
  builder.then = (onFulfilled: (value: QueryResult) => unknown) =>
    Promise.resolve(result).then(onFulfilled);
  return builder;
}

function supabase(result: QueryResult = { data: [question], error: null }) {
  const builder = query(result);
  const from = jest.fn(() => builder);
  return {
    builder,
    client: { schema: jest.fn(() => ({ from })) },
  };
}

function request(url: string, body?: unknown) {
  return {
    url,
    headers: {
      get: (name: string) =>
        name === 'content-type' && body ? 'application/json' : null,
    },
    json: async () => body,
  } as unknown as Request;
}

describe('examination-of-conscience routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('publicly returns the same selected question for identical date and filters', async () => {
    const fixture = supabase({
      data: [
        question,
        { ...question, id: 'e1000000-0000-4000-8000-000000000002' },
      ],
      error: null,
    });
    mockedCreateAdminClient.mockReturnValue(fixture.client as never);

    const url =
      'http://localhost/api/v1/examination-of-conscience?date=2026-08-22&category=single';
    const first = await getDailyQuestion(request(url));
    const second = await getDailyQuestion(request(url));

    expect((await first.json()).data).toEqual((await second.json()).data);
    expect((await first.json()).data).toMatchObject({
      type: 'mortal',
      isActive: true,
    });
    expect(fixture.builder.eq).toHaveBeenCalledWith('is_active', true);
    expect(fixture.builder.eq).toHaveBeenCalledWith('category', 'single');
  });

  it('returns 404 when public filters match no question', async () => {
    mockedCreateAdminClient.mockReturnValue(
      supabase({ data: [], error: null }).client as never,
    );

    const response = await getDailyQuestion(
      request(
        'http://localhost/api/v1/examination-of-conscience?saint=St.%20Joseph',
      ),
    );

    expect(response.status).toBe(404);
  });

  it('lets an administrator create a question and maps API type to database severity', async () => {
    const fixture = supabase({ data: question, error: null });
    mockedRequireAdmin.mockResolvedValue({ supabase: fixture.client } as never);

    const response = await POST(
      request('http://localhost/api/v1/admin/examination-of-conscience', {
        category: 'single',
        title: 'Faith',
        commandment: 1,
        type: 'mortal',
        question: question.question,
        description: question.description,
        counsels: question.counsels,
        prevention: question.prevention,
        saints: question.saints,
      }),
    );

    expect(fixture.builder.insert).toHaveBeenCalledWith(
      expect.objectContaining({ severity: 'mortal' }),
    );
    expect(response.status).toBe(201);
    expect((await response.json()).data).toMatchObject({ type: 'mortal' });
  });

  it('limits management routes to requireAdmin and supports update and delete', async () => {
    const listFixture = supabase({ data: [question], error: null });
    const updateFixture = supabase({ data: question, error: null });
    const deleteFixture = supabase({ data: { id: QUESTION_ID }, error: null });
    mockedRequireAdmin
      .mockResolvedValueOnce({ supabase: listFixture.client } as never)
      .mockResolvedValueOnce({ supabase: updateFixture.client } as never)
      .mockResolvedValueOnce({ supabase: deleteFixture.client } as never);
    const context = { params: Promise.resolve({ questionId: QUESTION_ID }) };

    const listResponse = await getAdminQuestions(
      request('http://localhost/api/v1/admin/examination-of-conscience'),
    );
    const updateResponse = await PATCH(
      request(
        `http://localhost/api/v1/admin/examination-of-conscience/${QUESTION_ID}`,
        {
          type: 'grave',
        },
      ),
      context,
    );
    const deleteResponse = await DELETE(
      request(
        `http://localhost/api/v1/admin/examination-of-conscience/${QUESTION_ID}`,
      ),
      context,
    );

    expect(mockedRequireAdmin).toHaveBeenCalledTimes(3);
    expect(updateFixture.builder.update).toHaveBeenCalledWith({
      severity: 'grave',
    });
    expect(listResponse.status).toBe(200);
    expect(updateResponse.status).toBe(200);
    expect(deleteResponse.status).toBe(204);
  });
});
