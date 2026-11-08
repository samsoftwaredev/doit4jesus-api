import { POST } from '../src/app/api/v1/internal/admin-notification-emails/process/route';
import { getEmailConfig } from '../src/lib/email/config';
import { sendDirectEmail } from '../src/lib/email/service';
import { renderAdminNotificationEmail } from '../src/lib/email/templates';
import { createAdminClient } from '../src/lib/supabase/admin';

jest.mock('../src/lib/email/config', () => ({ getEmailConfig: jest.fn() }));
jest.mock('../src/lib/email/service', () => ({ sendDirectEmail: jest.fn() }));
jest.mock('../src/lib/email/templates', () => ({
  renderAdminNotificationEmail: jest.fn(),
}));
jest.mock('../src/lib/supabase/admin', () => ({
  createAdminClient: jest.fn(),
}));
jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown) => ({ status: 200, json: async () => ({ data }) }),
  errorResponse: jest.fn((error: Error) => ({ status: 500, error })),
}));

const mockedCreateAdminClient = jest.mocked(createAdminClient);
const mockedGetEmailConfig = jest.mocked(getEmailConfig);
const mockedSendDirectEmail = jest.mocked(sendDirectEmail);
const mockedRender = jest.mocked(renderAdminNotificationEmail);

const job = {
  id: 'ae000000-0000-4000-8000-000000000001',
  category: 'church_schedule_review' as const,
  source_id: 'cc000000-0000-4000-8000-000000000001',
  recipient_user_id: '33333333-3333-4333-8333-333333333333',
  recipient_email: 'admin@example.com',
  subject: 'Church schedule needs to be entered',
  body: 'A followed church does not have a verified schedule.',
  action_url: '/dashboard?tab=admin&panel=churches&churchView=schedules',
  payload: {},
  status: 'processing' as const,
  attempt_count: 1,
  available_at: '2026-11-07T12:00:00.000Z',
  locked_at: '2026-11-07T12:00:00.000Z',
  sent_at: null,
  resend_email_id: null,
  last_error: null,
  created_at: '2026-11-07T12:00:00.000Z',
  updated_at: '2026-11-07T12:00:00.000Z',
};

function request(secret = 'worker-secret') {
  return {
    headers: {
      get: (name: string) =>
        name.toLowerCase() === 'authorization' ? `Bearer ${secret}` : null,
    },
  } as Request;
}

describe('POST internal admin notification email worker', () => {
  const originalSecret = process.env.ADMIN_NOTIFICATION_WORKER_SECRET;
  const originalResponse = global.Response;

  beforeAll(() => {
    global.Response = jest.fn((_body, init) => ({
      status: init?.status ?? 200,
    })) as never;
  });

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.ADMIN_NOTIFICATION_WORKER_SECRET = 'worker-secret';
    mockedGetEmailConfig.mockReturnValue({
      appUrl: 'https://api.example.com',
    } as never);
    mockedRender.mockResolvedValue({ html: '<p>Review</p>', text: 'Review' });
    mockedSendDirectEmail.mockResolvedValue('resend-email-1');
  });

  afterAll(() => {
    process.env.ADMIN_NOTIFICATION_WORKER_SECRET = originalSecret;
    global.Response = originalResponse;
  });

  it('rejects requests without the configured bearer secret', async () => {
    const response = await POST(request('wrong-secret'));
    expect(response.status).toBe(401);
    expect(mockedCreateAdminClient).not.toHaveBeenCalled();
  });

  it('claims, sends, logs, and completes a notification idempotently', async () => {
    const jobUpdateEq = jest.fn().mockResolvedValue({ error: null });
    const jobUpdate = jest.fn(() => ({ eq: jobUpdateEq }));
    const sendUpsert = jest.fn().mockResolvedValue({ error: null });
    const rpc = jest.fn().mockResolvedValue({ data: [job], error: null });
    const from = jest.fn((table: string) =>
      table === 'email_sends' ? { upsert: sendUpsert } : { update: jobUpdate },
    );
    mockedCreateAdminClient.mockReturnValue({
      schema: jest.fn(() => ({ rpc, from })),
    } as never);

    const response = await POST(request());

    expect(response.status).toBe(200);
    expect(mockedSendDirectEmail).toHaveBeenCalledWith(
      expect.objectContaining({
        to: 'admin@example.com',
        idempotencyKey: `admin-notification-${job.id}`,
      }),
    );
    expect(sendUpsert).toHaveBeenCalledWith(
      expect.objectContaining({
        admin_notification_email_job_id: job.id,
        kind: 'admin_notification',
        resend_email_id: 'resend-email-1',
      }),
      { onConflict: 'admin_notification_email_job_id' },
    );
    expect(jobUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'sent',
        resend_email_id: 'resend-email-1',
      }),
    );
    expect(await response.json()).toEqual({
      data: { claimed: 1, sent: 1, failed: 0, exhausted: 0 },
    });
  });

  it('retains failed jobs for a later retry', async () => {
    const jobUpdateEq = jest.fn().mockResolvedValue({ error: null });
    const jobUpdate = jest.fn(() => ({ eq: jobUpdateEq }));
    const rpc = jest.fn().mockResolvedValue({ data: [job], error: null });
    const from = jest.fn(() => ({ update: jobUpdate }));
    mockedCreateAdminClient.mockReturnValue({
      schema: jest.fn(() => ({ rpc, from })),
    } as never);
    mockedSendDirectEmail.mockRejectedValue(new Error('Resend unavailable'));

    const response = await POST(request());

    expect(jobUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'failed',
        locked_at: null,
        last_error: 'Resend unavailable',
      }),
    );
    expect(await response.json()).toEqual({
      data: { claimed: 1, sent: 0, failed: 1, exhausted: 0 },
    });
  });
});
