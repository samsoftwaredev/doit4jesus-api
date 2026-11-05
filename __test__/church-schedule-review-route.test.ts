import { PATCH } from '../src/app/api/v1/admin/church-schedule-reviews/[reviewId]/route';
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
      ],
      p_reason: null,
    });
  });
});
