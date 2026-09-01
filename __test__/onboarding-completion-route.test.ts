import { POST } from '../src/app/api/v1/me/onboarding/complete/route';
import { requireUser } from '../src/lib/auth/require-user';
import { loadNotificationPreferences } from '../src/lib/notifications/preferences';
import { loadCurrentProfile } from '../src/lib/profiles/current-profile';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/notifications/preferences', () => ({
  loadNotificationPreferences: jest.fn(),
}));
jest.mock('../src/lib/profiles/current-profile', () => ({
  loadCurrentProfile: jest.fn(),
}));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown, init: ResponseInit) => ({
    headers: new Headers(init.headers),
    json: async () => ({ data }),
  }),
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedLoadCurrentProfile = jest.mocked(loadCurrentProfile);
const mockedLoadNotificationPreferences = jest.mocked(
  loadNotificationPreferences,
);
const userId = '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002';
function request(body: unknown) {
  return {
    url: 'http://localhost/api/v1/me/onboarding/complete',
    headers: {
      get: (name: string) =>
        name === 'content-type' ? 'application/json' : null,
    },
    json: async () => body,
  } as Request;
}

describe('POST /api/v1/me/onboarding/complete', () => {
  it('atomically saves the normalized setup snapshot and returns refreshed state', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: { completedAt: '2026-08-28T12:00:00.000Z' },
      error: null,
    });
    const supabase = { schema: jest.fn(() => ({ rpc })) };
    const profile = {
      displayName: 'Samuel Ruiz',
      profileSetup: { complete: true, missingFields: [], nextStep: null },
    };
    const notificationPreferences = {
      dailyRosaryReminder: true,
      confessionReminder: false,
      eucharisticAdoration: true,
    };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);
    mockedLoadCurrentProfile.mockResolvedValue(profile as never);
    mockedLoadNotificationPreferences.mockResolvedValue(
      notificationPreferences,
    );

    const response = await POST(
      request({
        displayName: '  Samuel   Ruiz ',
        username: 'SamuelR',
        gender: 'male',
        countryCode: 'us',
        notificationPreferences,
      }),
    );

    expect(rpc).toHaveBeenCalledWith('complete_current_user_profile_setup', {
      p_display_name: 'Samuel Ruiz',
      p_username: 'SamuelR',
      p_gender: 'male',
      p_country_code: 'US',
      p_daily_rosary_reminder: true,
      p_confession_reminder: false,
      p_eucharistic_adoration: true,
    });
    expect(await response.json()).toEqual({
      data: { profile, notificationPreferences },
    });
    expect(response.headers.get('Cache-Control')).toBe('no-store');
  });

  it('blocks a prohibited username before invoking the completion RPC', async () => {
    const rpc = jest.fn();
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
      userId,
    } as never);

    await POST(
      request({
        displayName: 'Samuel Ruiz',
        username: 'faithful_fuck',
        gender: 'male',
        countryCode: 'US',
        notificationPreferences: {
          dailyRosaryReminder: true,
          confessionReminder: true,
          eucharisticAdoration: true,
        },
      }),
    );

    expect(rpc).not.toHaveBeenCalled();
  });

  it('accepts and normalizes a supported GB subdivision code', async () => {
    const rpc = jest.fn().mockResolvedValue({ data: {}, error: null });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
      userId,
    } as never);
    mockedLoadCurrentProfile.mockResolvedValue({} as never);
    mockedLoadNotificationPreferences.mockResolvedValue({} as never);

    await POST(
      request({
        displayName: 'Samuel Ruiz',
        username: 'SamuelR',
        gender: 'male',
        countryCode: 'gb-eng',
        notificationPreferences: {
          dailyRosaryReminder: true,
          confessionReminder: true,
          eucharisticAdoration: true,
        },
      }),
    );

    expect(rpc).toHaveBeenCalledWith('complete_current_user_profile_setup', {
      p_display_name: 'Samuel Ruiz',
      p_username: 'SamuelR',
      p_gender: 'male',
      p_country_code: 'GB-ENG',
      p_daily_rosary_reminder: true,
      p_confession_reminder: true,
      p_eucharistic_adoration: true,
    });
  });
});
