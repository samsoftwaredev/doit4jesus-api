import { POST } from '../src/app/api/v1/admin/churches/route';
import { errorResponse } from '../src/lib/api/response';
import { readJson } from '../src/lib/api/validation';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/validation', () => ({ readJson: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  errorResponse: jest.fn(),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const mockedReadJson = jest.mocked(readJson);
const church = {
  name: 'St. Missing Parish',
  addressLine1: '1 Overlooked Way',
  addressLine2: null,
  city: 'Austin',
  regionName: 'TX',
  postalCode: '78701',
  countryCode: 'US',
  timezone: 'America/Chicago',
  latitude: 30.27,
  longitude: -97.74,
};
const request = { url: 'http://localhost/api/v1/admin/churches' } as Request;

function mockRpc(result: { data: unknown; error: unknown }) {
  const rpc = jest.fn().mockResolvedValue(result);
  mockedRequireAdmin.mockResolvedValue({
    supabase: { schema: jest.fn(() => ({ rpc })) },
  } as never);
  return rpc;
}

describe('POST /api/v1/admin/churches', () => {
  beforeEach(() => jest.clearAllMocks());

  it('creates a church with a Mass-only schedule through the admin RPC', async () => {
    const rpc = mockRpc({ data: { churchId: 'new-church' }, error: null });
    mockedReadJson.mockResolvedValue({
      church,
      serviceTimes: [
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        {
          serviceType: 'confession',
          weekday: 'saturday',
          startTime: '16:00',
          endTime: '16:45',
        },
      ],
    });

    const response = await POST(request);

    expect(response.status).toBe(201);
    expect(rpc).toHaveBeenCalledWith('admin_create_church', {
      p_church: expect.objectContaining({
        name: 'St. Missing Parish',
        address_line_1: '1 Overlooked Way',
        region_name: 'TX',
        postal_code: '78701',
        country_code: 'US',
        latitude: 30.27,
      }),
      p_service_times: [
        { service_type: 'mass', weekday: 0, starts_at: '09:00', ends_at: null },
        {
          service_type: 'confession',
          weekday: 6,
          starts_at: '16:00',
          ends_at: '16:45',
        },
      ],
    });
  });

  it('rejects a church without a Mass time before calling the database', async () => {
    const rpc = mockRpc({ data: null, error: null });
    mockedReadJson.mockResolvedValue({
      church,
      serviceTimes: [
        { serviceType: 'adoration', weekday: 'friday', startTime: '18:00' },
      ],
    });

    await POST(request);

    expect(rpc).not.toHaveBeenCalled();
    expect(errorResponse).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'ZodError' }),
      request,
    );
  });

  it('rejects unknown properties and missing coordinates', async () => {
    const rpc = mockRpc({ data: null, error: null });
    mockedReadJson.mockResolvedValue({
      church: { ...church, latitude: undefined },
      serviceTimes: [
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
      ],
    });

    await POST(request);

    expect(rpc).not.toHaveBeenCalled();
    expect(errorResponse).toHaveBeenCalledTimes(1);
  });

  it('reports a duplicate church as a 409 conflict', async () => {
    mockRpc({
      data: null,
      error: { code: 'P0001', message: 'CHURCH_ALREADY_EXISTS' },
    });
    mockedReadJson.mockResolvedValue({
      church,
      serviceTimes: [
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
      ],
    });

    await POST(request);

    expect(errorResponse).toHaveBeenCalledWith(
      expect.objectContaining({ status: 409 }),
      request,
    );
  });

  it('reports a database-level missing Mass as a 422 validation error', async () => {
    mockRpc({
      data: null,
      error: { code: 'P0001', message: 'INCOMPLETE_CHURCH_SERVICE_TIMES' },
    });
    mockedReadJson.mockResolvedValue({
      church,
      serviceTimes: [
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
      ],
    });

    await POST(request);

    expect(errorResponse).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 422,
        message: 'At least one Mass time is required.',
      }),
      request,
    );
  });
});
