import { PATCH } from '../src/app/api/v1/admin/church-schedule-reviews/[reviewId]/route';
import { errorResponse } from '../src/lib/api/response';
import { readJson } from '../src/lib/api/validation';
import { requireAdmin } from '../src/lib/auth/require-admin';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/validation', () => ({ readJson: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown) => ({ status: 200, json: async () => ({ data }) }),
  errorResponse: jest.fn(),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const mockedReadJson = jest.mocked(readJson);
const reviewId = 'cc000000-0000-4000-8000-000000000001';

describe('PATCH /api/v1/admin/church-schedule-reviews/{reviewId}', () => {
  beforeEach(() => jest.clearAllMocks());

  it('maps a verified replacement schedule to the atomic review RPC', async () => {
    const rpc = jest.fn().mockResolvedValue({
      data: { reviewId, outcome: 'verified' },
      error: null,
    });
    mockedRequireAdmin.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);
    mockedReadJson.mockResolvedValue({
      decision: 'verified',
      church: { name: 'Holy Family Catholic Church' },
      serviceTimes: [
        {
          serviceType: 'mass',
          weekday: 'sunday',
          startTime: '09:00',
          endTime: null,
        },
        {
          serviceType: 'confession',
          weekday: 'saturday',
          startTime: '16:00',
          endTime: '16:45',
        },
        {
          serviceType: 'adoration',
          weekday: 'friday',
          startTime: '18:00',
          endTime: null,
        },
      ],
    });

    const response = await PATCH(
      {
        url: `http://localhost/api/v1/admin/church-schedule-reviews/${reviewId}`,
      } as Request,
      { params: Promise.resolve({ reviewId }) },
    );

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith('review_church_schedule_task', {
      p_review_id: reviewId,
      p_decision: 'verified',
      p_church: expect.objectContaining({
        name: 'Holy Family Catholic Church',
      }),
      p_service_times: [
        {
          service_type: 'mass',
          weekday: 0,
          starts_at: '09:00',
          ends_at: null,
        },
        {
          service_type: 'confession',
          weekday: 6,
          starts_at: '16:00',
          ends_at: '16:45',
        },
        {
          service_type: 'adoration',
          weekday: 5,
          starts_at: '18:00',
          ends_at: null,
        },
      ],
      p_reason: null,
    });
  });

  function mockRpc() {
    const rpc = jest.fn().mockResolvedValue({
      data: { reviewId, outcome: 'verified' },
      error: null,
    });
    mockedRequireAdmin.mockResolvedValue({
      supabase: { schema: jest.fn(() => ({ rpc })) },
    } as never);
    return rpc;
  }

  const patch = () =>
    PATCH(
      {
        url: `http://localhost/api/v1/admin/church-schedule-reviews/${reviewId}`,
      } as Request,
      { params: Promise.resolve({ reviewId }) },
    );

  it('accepts a Mass-only schedule because confession and adoration are optional', async () => {
    const rpc = mockRpc();
    mockedReadJson.mockResolvedValue({
      decision: 'verified',
      serviceTimes: [
        { serviceType: 'mass', weekday: 'sunday', startTime: '07:00' },
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        { serviceType: 'mass', weekday: 'sunday', startTime: '11:30' },
      ],
    });

    const response = await patch();

    expect(response.status).toBe(200);
    expect(rpc).toHaveBeenCalledWith(
      'review_church_schedule_task',
      expect.objectContaining({
        p_service_times: [
          {
            service_type: 'mass',
            weekday: 0,
            starts_at: '07:00',
            ends_at: null,
          },
          {
            service_type: 'mass',
            weekday: 0,
            starts_at: '09:00',
            ends_at: null,
          },
          {
            service_type: 'mass',
            weekday: 0,
            starts_at: '11:30',
            ends_at: null,
          },
        ],
      }),
    );
  });

  it('rejects a schedule without any Mass time before calling the database', async () => {
    const rpc = mockRpc();
    mockedReadJson.mockResolvedValue({
      decision: 'verified',
      serviceTimes: [
        { serviceType: 'confession', weekday: 'saturday', startTime: '16:00' },
        { serviceType: 'adoration', weekday: 'friday', startTime: '18:00' },
      ],
    });

    await patch();

    expect(rpc).not.toHaveBeenCalled();
    expect(errorResponse).toHaveBeenCalledWith(
      expect.objectContaining({
        issues: [
          expect.objectContaining({
            message: 'At least one Mass time is required.',
          }),
        ],
      }),
      expect.anything(),
    );
  });

  it('collapses repeated service times so the unique key is never violated', async () => {
    const rpc = mockRpc();
    mockedReadJson.mockResolvedValue({
      decision: 'verified',
      serviceTimes: [
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
      ],
    });

    await patch();

    expect(rpc.mock.calls[0]?.[1].p_service_times).toHaveLength(1);
  });
});
