/** @jest-environment node */
import { NextRequest } from 'next/server';

import { GET } from '../src/auth/callback/route';
import { createClient } from '../src/lib/supabase/server';

jest.mock('../src/lib/supabase/server', () => ({
  createClient: jest.fn(),
}));

const mockedCreateClient = jest.mocked(createClient);
const exchangeCodeForSession = jest.fn();

describe('/auth/callback', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedCreateClient.mockResolvedValue({
      auth: { exchangeCodeForSession },
    } as never);
    exchangeCodeForSession.mockResolvedValue({ error: null });
  });

  it('exchanges the PKCE code and redirects to the requested local path', async () => {
    const request = new NextRequest(
      'http://localhost:3000/auth/callback?code=oauth-code&next=%2Fdashboard%3Ftab%3Dusers',
    );

    const response = await GET(request);

    expect(exchangeCodeForSession).toHaveBeenCalledWith('oauth-code');
    expect(response.headers.get('location')).toBe(
      'http://localhost:3000/dashboard?tab=users',
    );
  });

  it('does not redirect to an external next URL', async () => {
    const request = new NextRequest(
      'http://localhost:3000/auth/callback?code=oauth-code&next=%2F%2Fevil.example%2Faccount',
    );

    const response = await GET(request);

    expect(response.headers.get('location')).toBe('http://localhost:3000/');
  });

  it('redirects to the auth error page when the code is missing', async () => {
    const request = new NextRequest(
      'http://localhost:3000/auth/callback?next=%2Fdashboard',
    );

    const response = await GET(request);

    expect(mockedCreateClient).not.toHaveBeenCalled();
    expect(exchangeCodeForSession).not.toHaveBeenCalled();
    expect(response.headers.get('location')).toBe(
      'http://localhost:3000/auth/error',
    );
  });

  it('redirects to the auth error page when the exchange fails', async () => {
    exchangeCodeForSession.mockResolvedValue({
      error: new Error('Invalid code'),
    });
    const request = new NextRequest(
      'http://localhost:3000/auth/callback?code=invalid-code',
    );

    const response = await GET(request);

    expect(response.headers.get('location')).toBe(
      'http://localhost:3000/auth/error',
    );
  });
});
