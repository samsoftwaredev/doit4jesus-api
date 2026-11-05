import { GET as GET_UPCOMING } from '../src/app/api/v1/me/church-services/upcoming/route';
import {
  DELETE,
  PATCH,
} from '../src/app/api/v1/me/church-subscriptions/[churchId]/route';
import { POST } from '../src/app/api/v1/me/church-subscriptions/route';
import { readJson } from '../src/lib/api/validation';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({ requireUser: jest.fn() }));
jest.mock('../src/lib/api/validation', () => ({ readJson: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  ok: (data: unknown, _init?: ResponseInit, meta?: unknown) => ({
    status: 200,
    json: async () => (meta ? { data, meta } : { data }),
  }),
  noContent: () => ({ status: 204 }),
  errorResponse: jest.fn(),
}));

const mockedRequireUser = jest.mocked(requireUser);
const mockedReadJson = jest.mocked(readJson);
const churchId = 'c6000000-0000-4000-8000-000000000001';
const requestHeaders = new Headers({ 'x-request-id': 'test-request-id' });

function authenticatedRpc(result: { data: unknown; error: null }) {
  const rpc = jest.fn().mockResolvedValue(result);
  mockedRequireUser.mockResolvedValue({
    userId: '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
    supabase: { schema: jest.fn(() => ({ rpc })) },
  } as never);
  return rpc;
}

describe('church subscription routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('creates a subscription and maps weekday names to database values', async () => {
    const rpc = authenticatedRpc({
      data: { id: 'cb000000-0000-4000-8000-000000000001', churchId },
      error: null,
    });
    mockedReadJson.mockResolvedValue({
      churchId,
      serviceTypes: ['mass', 'confession'],
      notificationWeekdays: ['sunday', 'wednesday'],
    });
    const response = await POST({
      url: 'http://localhost/api/v1/me/church-subscriptions',
      headers: requestHeaders,
    } as Request);

    expect(response.status).toBe(201);
    expect(rpc).toHaveBeenCalledWith('create_church_subscription', {
      p_church_id: churchId,
      p_service_types: ['mass', 'confession'],
      p_notification_weekdays: [0, 3],
    });
  });

  it('updates selected preferences without replacing omitted preferences', async () => {
    const rpc = authenticatedRpc({
      data: { churchId, updated: true },
      error: null,
    });
    mockedReadJson.mockResolvedValue({ notificationWeekdays: ['friday'] });
    const response = await PATCH(
      {
        url: `http://localhost/api/v1/me/church-subscriptions/${churchId}`,
        headers: requestHeaders,
      } as Request,
      { params: Promise.resolve({ churchId }) },
    );

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith('update_church_subscription', {
      p_church_id: churchId,
      p_service_types: null,
      p_notification_weekdays: [5],
    });
  });

  it('deletes a subscription with an empty response body', async () => {
    const rpc = authenticatedRpc({ data: {}, error: null });
    const response = await DELETE(
      {
        url: `http://localhost/api/v1/me/church-subscriptions/${churchId}`,
        headers: requestHeaders,
      } as Request,
      { params: Promise.resolve({ churchId }) },
    );

    expect(response.status).toBe(204);
    expect(rpc).toHaveBeenCalledWith('delete_church_subscription', {
      p_church_id: churchId,
    });
  });

  it('returns dated upcoming occurrences with bounded pagination', async () => {
    const rpc = authenticatedRpc({
      data: [
        {
          occurrence_id: 'service:sunday',
          service_time_id: 'c7000000-0000-4000-8000-000000000001',
          church_id: churchId,
          church_name: 'St. Mary Cathedral',
          service_type: 'mass',
          starts_at: '2026-11-01T14:00:00Z',
          ends_at: '2026-11-01T15:00:00Z',
          local_date: '2026-11-01',
          local_start_time: '08:00:00',
          local_end_time: null,
          timezone: 'America/Chicago',
        },
      ],
      error: null,
    });
    const response = await GET_UPCOMING({
      url: `http://localhost/api/v1/me/church-services/upcoming?from=2026-10-31T13:00:00Z&days=7&churchId=${churchId}`,
      headers: requestHeaders,
    } as Request);

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith(
      'get_my_upcoming_church_services',
      expect.objectContaining({
        p_from: '2026-10-31T13:00:00Z',
        p_days: 7,
        p_church_id: churchId,
        p_limit: 51,
      }),
    );
    expect(await response.json()).toEqual(
      expect.objectContaining({
        data: [
          expect.objectContaining({
            occurrenceId: 'service:sunday',
            localStartTime: '08:00',
          }),
        ],
      }),
    );
  });
});
