import { POST } from '../src/app/api/v1/admin/email/campaigns/route';
import { requireAdmin } from '../src/lib/auth/require-admin';
import { getEmailConfig } from '../src/lib/email/config';
import { renderCampaignEmail } from '../src/lib/email/templates';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/email/config', () => ({ getEmailConfig: jest.fn() }));
jest.mock('../src/lib/email/templates', () => ({
  renderCampaignEmail: jest.fn(),
}));
jest.mock('../src/lib/api/response', () => ({
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  errorResponse: jest.fn(),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const mockedGetEmailConfig = jest.mocked(getEmailConfig);
const mockedRenderCampaignEmail = jest.mocked(renderCampaignEmail);

describe('POST /api/v1/admin/email/campaigns', () => {
  beforeEach(() => jest.clearAllMocks());

  it('creates a rendered administrator campaign draft', async () => {
    const campaign = {
      id: 'e0000000-0000-4000-8000-000000000001',
      template_key: 'update',
      subject: 'This week in prayer',
      content: { previewText: 'Preview', heading: 'Heading', body: 'Body' },
      rendered_html: '<html />',
      status: 'draft',
      recipient_count: 0,
      resend_broadcast_id: null,
      scheduled_for: null,
      sent_at: null,
      last_tested_revision: null,
      created_by: '33333333-3333-4333-8333-333333333333',
      created_at: '2026-10-12T12:00:00.000Z',
      updated_at: '2026-10-12T12:00:00.000Z',
    };
    const single = jest.fn().mockResolvedValue({ data: campaign, error: null });
    const select = jest.fn(() => ({ single }));
    const insert = jest.fn(() => ({ select }));
    mockedRequireAdmin.mockResolvedValue({
      userId: campaign.created_by,
      supabase: {
        schema: jest.fn(() => ({ from: jest.fn(() => ({ insert })) })),
      },
    } as never);
    mockedGetEmailConfig.mockReturnValue({
      apiKey: 're_test',
      from: 'Do It 4 Jesus <updates@example.com>',
      replyTo: 'support@example.com',
      physicalAddress: '123 Main St',
      segmentId: 'segment',
      appUrl: 'https://example.com',
    });
    mockedRenderCampaignEmail.mockResolvedValue({
      html: '<html />',
      text: 'Body',
    });

    const response = await POST({
      headers: { get: jest.fn(() => 'application/json') },
      json: async () => ({
        templateKey: 'update',
        subject: 'This week in prayer',
        content: { previewText: 'Preview', heading: 'Heading', body: 'Body' },
      }),
    } as unknown as Request);

    expect(mockedRenderCampaignEmail).toHaveBeenCalledWith(
      'update',
      expect.any(Object),
      {
        physicalAddress: '123 Main St',
        unsubscribeUrl: 'https://example.com/email-preferences',
      },
    );
    expect(insert).toHaveBeenCalledWith(
      expect.objectContaining({
        template_key: 'update',
        subject: 'This week in prayer',
        rendered_html: '<html />',
        created_by: campaign.created_by,
      }),
    );
    expect(response.status).toBe(201);
  });
});
