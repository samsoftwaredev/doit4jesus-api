import { POST } from '../src/app/api/v1/me/daily-scripture/completions/route';
import { errorResponse } from '../src/lib/api/response';
import { requireUser } from '../src/lib/auth/require-user';
import { getMassReadings } from '../src/liturgy/MassReadingsService';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/liturgy/MassReadingsService', () => ({
  getMassReadings: jest.fn(),
}));
jest.mock('../src/lib/api/response', () => ({
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  ok: (data: unknown) => ({ status: 200, json: async () => ({ data }) }),
  errorResponse: jest.fn(),
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedGetMassReadings = jest.mocked(getMassReadings);
const mockedErrorResponse = jest.mocked(errorResponse);

function request(body: unknown, idempotencyKey = 'daily-scripture-1') {
  return {
    headers: {
      get: (name: string) =>
        name === 'content-type'
          ? 'application/json'
          : name === 'idempotency-key'
            ? idempotencyKey
            : null,
    },
    json: async () => body,
  } as Request;
}

describe('POST /api/v1/me/daily-scripture/completions', () => {
  beforeEach(() => jest.clearAllMocks());

  it('validates the reading and creates the caller completion', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: { replayed: false, completion: { readingDate: '2026-09-25' } },
      error: null,
    });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);
    mockedGetMassReadings.mockResolvedValue({ date: '2026-09-25' } as never);

    const response = await POST(request({ readingDate: '2026-09-25' }));

    expect(mockedGetMassReadings).toHaveBeenCalledWith({
      date: '2026-09-25',
      country: 'US',
      includeVerseText: false,
    });
    expect(rpc).toHaveBeenCalledWith('complete_daily_scripture', {
      p_reading_date: '2026-09-25',
      p_idempotency_key: 'daily-scripture-1',
    });
    expect(response.status).toBe(201);
  });

  it('returns the original completion for a replay', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: { replayed: true, completion: { readingDate: '2026-09-25' } },
      error: null,
    });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);
    mockedGetMassReadings.mockResolvedValue({ date: '2026-09-25' } as never);

    const response = await POST(request({ readingDate: '2026-09-25' }));

    expect(response.status).toBe(200);
  });

  it('does not create a completion when the USCCB reading is unavailable', async () => {
    const rpc = jest.fn();
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);
    mockedGetMassReadings.mockRejectedValue(new Error('READINGS_NOT_FOUND'));

    await POST(request({ readingDate: '2027-09-25' }));

    expect(rpc).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledWith(
      expect.any(Error),
      expect.anything(),
    );
  });
});
