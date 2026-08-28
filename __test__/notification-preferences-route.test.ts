import {
  GET,
  PATCH,
} from '../src/app/api/v1/me/notification-preferences/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);
const userId = '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002';

function preferenceQuery(data: unknown) {
  const query: Record<string, jest.Mock> = {};
  query.select = jest.fn().mockReturnValue(query);
  query.eq = jest.fn().mockReturnValue(query);
  query.maybeSingle = jest.fn().mockResolvedValue({ data, error: null });
  return query;
}

describe('/api/v1/me/notification-preferences', () => {
  it('returns enabled defaults when a legacy profile has no preference row', async () => {
    const from = jest.fn().mockReturnValue(preferenceQuery(null));
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId,
    } as never);

    const response = await GET({ url: 'http://localhost' } as Request);

    expect(await response.json()).toEqual({
      data: {
        dailyRosaryReminder: true,
        confessionReminder: true,
        eucharisticAdoration: true,
      },
    });
    expect(response.headers.get('Cache-Control')).toBe('no-store');
  });

  it('incrementally saves preferences and returns the persisted values', async () => {
    const upsert = jest.fn().mockResolvedValue({ error: null });
    const persisted = preferenceQuery({
      daily_rosary_reminder: true,
      confession_reminder: false,
      eucharistic_adoration: true,
    });
    const from = jest
      .fn()
      .mockReturnValueOnce({ upsert })
      .mockReturnValueOnce(persisted);
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ from })) },
      userId,
    } as never);

    const response = await PATCH({
      url: 'http://localhost',
      headers: {
        get: (name: string) =>
          name === 'content-type' ? 'application/json' : null,
      },
      json: async () => ({ confessionReminder: false }),
    } as Request);

    expect(upsert).toHaveBeenCalledWith(
      { user_id: userId, confession_reminder: false },
      { onConflict: 'user_id' },
    );
    expect(await response.json()).toEqual({
      data: {
        dailyRosaryReminder: true,
        confessionReminder: false,
        eucharisticAdoration: true,
      },
    });
  });
});
