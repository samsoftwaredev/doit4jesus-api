/** @jest-environment node */
import { NextRequest } from 'next/server';

import { updateSession } from '../src/lib/supabase/proxy';
import { proxy } from '../src/proxy';

jest.mock('../src/lib/supabase/proxy', () => ({
  updateSession: jest.fn(),
}));

const mockedUpdateSession = jest.mocked(updateSession);

describe('API CORS proxy', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('allows the Idempotency-Key header in localhost preflight requests', async () => {
    const request = new NextRequest('http://localhost:3000/api/v1/activities', {
      method: 'OPTIONS',
      headers: {
        origin: 'http://localhost:8081',
        'access-control-request-method': 'POST',
        'access-control-request-headers':
          'authorization, content-type, idempotency-key',
      },
    });

    const response = await proxy(request);
    const allowedHeaders =
      response.headers
        .get('Access-Control-Allow-Headers')
        ?.toLowerCase()
        .split(',')
        .map((header) => header.trim()) ?? [];

    expect(response.status).toBe(204);
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe(
      'http://localhost:8081',
    );
    expect(allowedHeaders).toContain('idempotency-key');
    expect(mockedUpdateSession).not.toHaveBeenCalled();
  });

  it('refreshes the cookie session for regular requests', async () => {
    const refreshedResponse = new Response(null, {
      headers: { 'x-session-refreshed': 'true' },
    });
    mockedUpdateSession.mockResolvedValue(refreshedResponse as never);
    const request = new NextRequest('http://localhost:3000/dashboard');

    const response = await proxy(request);

    expect(mockedUpdateSession).toHaveBeenCalledWith(request);
    expect(response.headers.get('x-session-refreshed')).toBe('true');
  });

  it('adds localhost API CORS headers to the refreshed session response', async () => {
    const refreshedResponse = new Response(null, {
      headers: { 'x-session-refreshed': 'true' },
    });
    mockedUpdateSession.mockResolvedValue(refreshedResponse as never);
    const request = new NextRequest('http://localhost:3000/api/v1/activities', {
      headers: { origin: 'http://localhost:8081' },
    });

    const response = await proxy(request);

    expect(mockedUpdateSession).toHaveBeenCalledWith(request);
    expect(response.headers.get('x-session-refreshed')).toBe('true');
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe(
      'http://localhost:8081',
    );
    expect(response.headers.get('Access-Control-Allow-Headers')).toContain(
      'Idempotency-Key',
    );
  });
});
