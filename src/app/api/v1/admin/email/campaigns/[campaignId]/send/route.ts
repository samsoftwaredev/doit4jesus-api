import { z } from 'zod';

import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { getEmailConfig } from '@/lib/email/config';
import { toEmailCampaign } from '@/lib/email/serializers';
import {
  campaignContent,
  campaignRevision,
  createCampaignBroadcast,
  syncCampaignSegment,
} from '@/lib/email/service';
import { renderCampaignEmail } from '@/lib/email/templates';
import { scheduleEmailCampaignSchema } from '@/lib/schemas/email';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ campaignId: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const campaignId = z.uuid().parse((await context.params).campaignId);
    const input = scheduleEmailCampaignSchema.parse(await readJson(request));
    if (
      input.scheduledFor &&
      new Date(input.scheduledFor).valueOf() <= Date.now()
    )
      throw new ApiError(
        422,
        'VALIDATION_ERROR',
        'scheduledFor must be in the future.',
      );

    const { supabase } = await requireAdmin(request);
    const { data: campaign, error: campaignError } = await supabase
      .schema('app')
      .from('email_campaigns')
      .select('*')
      .eq('id', campaignId)
      .single();
    throwDatabaseError(campaignError, 'Unable to load the email campaign.');
    if (campaign.status !== 'draft')
      throw ApiError.conflict(
        'Only draft email campaigns can be sent or scheduled.',
      );

    const { data: testRecipients, error: testRecipientsError } = await supabase
      .schema('app')
      .from('email_test_recipients')
      .select('email')
      .order('email');
    throwDatabaseError(testRecipientsError, 'Unable to load test recipients.');
    const revision = campaignRevision(
      campaign,
      (testRecipients ?? []).map((recipient) => recipient.email),
    );
    if (
      !campaign.last_tested_revision ||
      campaign.last_tested_revision !== revision
    )
      throw ApiError.conflict(
        'Send a successful test to every saved test recipient before launch.',
      );

    const config = getEmailConfig();
    const providerTemplate = await renderCampaignEmail(
      campaign.template_key,
      campaignContent(campaign.content),
      {
        physicalAddress: config.physicalAddress,
        unsubscribeUrl: '{{{RESEND_UNSUBSCRIBE_URL}}}',
      },
    );
    const recipients = await syncCampaignSegment(createAdminClient());
    if (recipients.length === 0)
      throw ApiError.conflict(
        'There are no eligible active recipients for this campaign.',
      );

    const resendBroadcastId = await createCampaignBroadcast({
      campaign: { ...campaign, rendered_html: providerTemplate.html },
      scheduledFor: input.scheduledFor,
    });
    const now = new Date().toISOString();
    const { data, error } = await supabase
      .schema('app')
      .from('email_campaigns')
      .update({
        rendered_html: providerTemplate.html,
        status: input.scheduledFor ? 'scheduled' : 'sent',
        recipient_count: recipients.length,
        resend_broadcast_id: resendBroadcastId,
        scheduled_for: input.scheduledFor ?? null,
        sent_at: input.scheduledFor ? null : now,
      })
      .eq('id', campaign.id)
      .select('*')
      .single();
    throwDatabaseError(error, 'Unable to record the email campaign launch.');
    return ok(toEmailCampaign(data));
  } catch (error) {
    return errorResponse(error, request);
  }
}
