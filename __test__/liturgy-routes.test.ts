import { GET as getReadings } from '../src/app/api/v1/liturgy/readings/[date]/route';
import { GET as getToday } from '../src/app/api/v1/liturgy/today/route';
import { requireUser } from '../src/lib/auth/require-user';
import {
  applicationToday,
  getMassReadings,
} from '../src/liturgy/MassReadingsService';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit = {}) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
}));
jest.mock('../src/liturgy/MassReadingsService', () => ({
  applicationToday: jest.fn(),
  getMassReadings: jest.fn(),
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedGetMassReadings = jest.mocked(getMassReadings);
const mockedApplicationToday = jest.mocked(applicationToday);

const payload = {
  date: '2026-08-21',
  celebration: {
    id: 'saint-pius-x',
    name: 'Memorial of Saint Pius X, Pope',
    grade: 'MEMORIAL' as const,
    season: 'ORDINARY_TIME' as const,
    color: ['WHITE' as const],
  },
  cycles: {
    sunday: 'A' as const,
    weekday: 'II' as const,
    psalterWeek: 4 as const,
  },
  readings: [{ type: 'GOSPEL' as const, citation: 'Mt 22:34-40' }],
};

describe('liturgy routes', () => {
  beforeEach(() => {
    mockedRequireUser.mockResolvedValue({ userId: 'user-id' } as never);
    mockedGetMassReadings.mockResolvedValue(payload);
    mockedApplicationToday.mockReturnValue('2026-08-21');
  });

  it('serves a validated day through the versioned readings route', async () => {
    const response = await getReadings(
      {
        url: 'http://localhost/api/v1/liturgy/readings/2026-08-21?country=US&diocese=dallas',
      } as Request,
      { params: Promise.resolve({ date: '2026-08-21' }) },
    );

    expect(await response.json()).toEqual({ data: payload });
    expect(response.headers.get('Content-Language')).toBe('en');
    expect(mockedGetMassReadings).toHaveBeenCalledWith({
      date: '2026-08-21',
      country: 'US',
      diocese: 'dallas',
      locale: undefined,
      includeVerseText: true,
    });
  });

  it('marks Spanish Scripture responses with their content language', async () => {
    const spanishPayload = {
      ...payload,
      metadata: {
        dataVersion: 'v3',
        locale: 'es-MX',
        scriptureTextSource: 'BIBLIA_DE_JERUSALEN' as const,
      },
    };
    mockedGetMassReadings.mockResolvedValueOnce(spanishPayload);

    const response = await getReadings(
      {
        url: 'http://localhost/api/v1/liturgy/readings/2026-08-21?locale=es-MX',
      } as Request,
      { params: Promise.resolve({ date: '2026-08-21' }) },
    );

    expect(await response.json()).toEqual({ data: spanishPayload });
    expect(response.headers.get('Content-Language')).toBe('es');
    expect(mockedGetMassReadings).toHaveBeenCalledWith({
      date: '2026-08-21',
      country: undefined,
      diocese: undefined,
      locale: 'es-MX',
      includeVerseText: true,
    });
  });

  it('uses the configured local date in the today route', async () => {
    const response = await getToday({
      url: 'http://localhost/api/v1/liturgy/today',
    } as Request);

    expect(await response.json()).toEqual({ data: payload });
    expect(mockedApplicationToday).toHaveBeenCalledWith();
    expect(mockedGetMassReadings).toHaveBeenCalledWith({
      date: '2026-08-21',
      country: undefined,
      diocese: undefined,
      locale: undefined,
      includeVerseText: true,
    });
  });
});
