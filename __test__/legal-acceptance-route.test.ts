import { POST } from '../src/app/api/v1/me/legal-acceptance/route';
import { errorResponse } from '../src/lib/api/response';
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
const mockedErrorResponse = jest.mocked(errorResponse);

function request(body: unknown) {
  return {
    url: 'http://localhost/api/v1/me/legal-acceptance',
    headers: {
      get: (name: string) =>
        name === 'content-type' ? 'application/json' : null,
    },
    json: async () => body,
  } as Request;
}

describe('POST /api/v1/me/legal-acceptance', () => {
  beforeEach(() => jest.clearAllMocks());

  it('records server-owned versions and returns the current acceptance status', async () => {
    const acceptedAt = '2026-10-27T06:00:00.000Z';
    const rpc = jest
      .fn()
      .mockResolvedValueOnce({ data: { acceptedAt }, error: null })
      .mockResolvedValueOnce({
        data: {
          accountCreatedAt: '2026-10-27T05:00:00.000Z',
          acceptedAt,
        },
        error: null,
      });
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    const response = await POST(
      request({
        locale: 'es',
        adultConfirmed: true,
        usResidentConfirmed: true,
      }),
    );

    expect(rpc).toHaveBeenNthCalledWith(
      1,
      'accept_current_user_legal_documents',
      {
        p_accepted_locale: 'es',
        p_adult_confirmed: true,
        p_us_resident_confirmed: true,
      },
    );
    expect(rpc).toHaveBeenNthCalledWith(2, 'get_current_user_legal_status');
    expect(await response.json()).toEqual({
      data: expect.objectContaining({
        required: false,
        accepted: true,
        grandfathered: false,
        termsVersion: '2026-10-28',
        privacyVersion: '2026-10-28',
        communityGuidelinesVersion: '2026-10-28',
        acceptedAt,
      }),
    });
    expect(response.headers.get('Cache-Control')).toBe('no-store');
  });

  it.each([
    { locale: 'fr', adultConfirmed: true, usResidentConfirmed: true },
    { locale: 'en', adultConfirmed: false, usResidentConfirmed: true },
    { locale: 'en', adultConfirmed: true, usResidentConfirmed: false },
    {
      locale: 'en',
      adultConfirmed: true,
      usResidentConfirmed: true,
      termsVersion: 'client-controlled',
    },
  ])('rejects invalid or client-owned input %#', async (body) => {
    const rpc = jest.fn();
    mockedRequireUser.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);

    await POST(request(body));

    expect(rpc).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'ZodError' }),
      expect.anything(),
    );
  });
});
