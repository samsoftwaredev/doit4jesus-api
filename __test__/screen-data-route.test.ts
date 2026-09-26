import { GET } from '../src/app/api/v1/screen-data/route';
import { errorResponse } from '../src/lib/api/response';
import { requireUser } from '../src/lib/auth/require-user';
import * as loaders from '../src/lib/screen-data/loaders';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn((error: unknown) => ({ status: 500, error })),
  ok: (data: unknown, init: ResponseInit, meta: unknown) => ({
    status: 200,
    headers: new Headers(init.headers),
    json: async () => ({ data, meta }),
  }),
}));
jest.mock('../src/lib/screen-data/loaders', () => ({
  loadActivities: jest.fn(),
  loadBadges: jest.fn(),
  loadCurrentUser: jest.fn(),
  loadExaminationQuestion: jest.fn(),
  loadFriends: jest.fn(),
  loadFriendsLeaderboard: jest.fn(),
  loadIncomingFriendRequests: jest.fn(),
  loadLeaderboard: jest.fn(),
  loadLevels: jest.fn(),
  loadLiturgyToday: jest.fn(),
  loadPrayerIntentions: jest.fn(),
  loadProgress: jest.fn(),
  loadRosaryCompletion: jest.fn(),
  loadRosaryReminder: jest.fn(),
  loadRosaryStats: jest.fn(),
  loadRosaryStreak: jest.fn(),
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedLoaders = jest.mocked(loaders);
const context = {
  supabase: {},
  userId: '11111111-1111-4111-8111-111111111111',
} as never;
const section = { data: { loaded: true } };

function request(url: string) {
  return { url, headers: { get: () => null } } as Request;
}

function mockAllLoaders() {
  Object.values(mockedLoaders).forEach((loader) => {
    if (typeof loader === 'function')
      (loader as jest.Mock).mockResolvedValue(section);
  });
}

describe('GET /api/v1/screen-data', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedRequireUser.mockResolvedValue(context);
    mockAllLoaders();
  });

  it('loads the Home snapshot with its fixed activity requests and forwarded liturgy context', async () => {
    const response = await GET(
      request(
        'http://localhost/api/v1/screen-data?screen=home&country=US&diocese=dallas&locale=es-MX',
      ),
    );
    const body = await response.json();

    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(body.data.screen).toBe('home');
    expect(body.data.sections).toMatchObject({
      rosaryStreak: section,
      badges: section,
    });
    expect(mockedLoaders.loadActivities).toHaveBeenCalledWith(
      context,
      'SCRIPTURE',
    );
    expect(mockedLoaders.loadActivities).toHaveBeenCalledWith(
      context,
      'ROSARY',
    );
    expect(mockedLoaders.loadLiturgyToday).toHaveBeenCalledWith(context, {
      screen: 'home',
      country: 'US',
      diocese: 'dallas',
      locale: 'es-MX',
    });
  });

  it('loads the Prayer snapshot with completion context and fixed leaderboard limits', async () => {
    const response = await GET(
      request(
        'http://localhost/api/v1/screen-data?screen=prayer&selectedMonth=7&selectedYear=2026',
      ),
    );

    expect((await response.json()).data.sections).toMatchObject({
      prayerIntentions: section,
      me: section,
    });
    expect(mockedLoaders.loadRosaryCompletion).toHaveBeenCalledWith(context, {
      screen: 'prayer',
      selectedMonth: 7,
      selectedYear: 2026,
    });
    expect(mockedLoaders.loadLeaderboard).toHaveBeenCalledWith(
      context,
      'weekly',
      3,
    );
    expect(mockedLoaders.loadLeaderboard).toHaveBeenCalledWith(
      context,
      'yearly',
      10,
    );
  });

  it('returns null and a safe error for an isolated section failure', async () => {
    mockedLoaders.loadFriends.mockRejectedValue(
      new Error('database credentials'),
    );
    const response = await GET(
      request('http://localhost/api/v1/screen-data?screen=community'),
    );
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.data.sections.friends).toBeNull();
    expect(body.meta.errors.friends).toEqual({
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred.',
    });
    expect(body.data.sections.incomingFriendRequests).toEqual(section);
  });

  it('uses the normal validation response for missing or unknown query fields', async () => {
    await GET(request('http://localhost/api/v1/screen-data?extra=value'));
    expect(errorResponse).toHaveBeenCalled();
  });

  it('uses the normal authentication error response before loading sections', async () => {
    mockedRequireUser.mockRejectedValue(new Error('unauthenticated'));

    await GET(request('http://localhost/api/v1/screen-data?screen=home'));

    expect(errorResponse).toHaveBeenCalled();
    expect(mockedLoaders.loadRosaryStreak).not.toHaveBeenCalled();
  });
});
