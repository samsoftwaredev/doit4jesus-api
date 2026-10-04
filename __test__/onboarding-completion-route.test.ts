import { POST } from '../src/app/api/v1/me/onboarding/complete/route';
import { requireUser } from '../src/lib/auth/require-user';
import { loadCurrentProfile } from '../src/lib/profiles/current-profile';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
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
  it('atomically saves the normalized setup snapshot and returns the refreshed profile', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: { completedAt: '2026-08-28T12:00:00.000Z' },
      error: null,
    });
    const supabase = { schema: jest.fn(() => ({ rpc })) };
    const profile = {
      displayName: 'Samuel Ruiz',
      profileSetup: { complete: true, missingFields: [], nextStep: null },
    };
    mockedRequireUser.mockResolvedValue({ supabase, userId } as never);
    mockedLoadCurrentProfile.mockResolvedValue(profile as never);

    const response = await POST(
      request({
        displayName: '  Samuel   Ruiz ',
        username: 'SamuelR',
        gender: 'male',
        countryCode: 'us',
      }),
    );

    expect(rpc).toHaveBeenCalledWith('complete_current_user_profile_setup', {
      p_display_name: 'Samuel Ruiz',
      p_username: 'SamuelR',
      p_gender: 'male',
      p_country_code: 'US',
    });
    expect(await response.json()).toEqual({
      data: { profile },
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

    await POST(
      request({
        displayName: 'Samuel Ruiz',
        username: 'SamuelR',
        gender: 'male',
        countryCode: 'gb-eng',
      }),
    );

    expect(rpc).toHaveBeenCalledWith('complete_current_user_profile_setup', {
      p_display_name: 'Samuel Ruiz',
      p_username: 'SamuelR',
      p_gender: 'male',
      p_country_code: 'GB-ENG',
    });
  });

  it('rejects notification preferences as an unknown onboarding field', async () => {
    const rpc = jest.fn();
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
      userId,
    } as never);

    await POST(
      request({
        displayName: 'Samuel Ruiz',
        username: 'SamuelR',
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
});
