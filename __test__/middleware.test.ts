/** @jest-environment node */
import { NextRequest } from 'next/server';

import { proxy } from '../src/proxy';

describe('API CORS proxy', () => {
  it('allows the Idempotency-Key header in localhost preflight requests', () => {
    const request = new NextRequest('http://localhost:3000/api/v1/activities', {
      method: 'OPTIONS',
      headers: {
        origin: 'http://localhost:8081',
        'access-control-request-method': 'POST',
        'access-control-request-headers':
          'authorization, content-type, idempotency-key',
      },
    });

    const response = proxy(request);
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
  });
});
