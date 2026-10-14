import { z } from 'zod';

import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { getEmailConfig } from '@/lib/email/config';
import {
  campaignContent,
  campaignRevision,
  sendDirectEmail,
} from '@/lib/email/service';
import { renderCampaignEmail } from '@/lib/email/templates';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ campaignId: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const campaignId = z.uuid().parse((await context.params).campaignId);
    const { supabase, userId } = await requireAdmin(request);
    const { data: campaign, error: campaignError } = await supabase
      .schema('app')
      .from('email_campaigns')
      .select('*')
      .eq('id', campaignId)
      .single();
    throwDatabaseError(campaignError, 'Unable to load the email campaign.');
    if (campaign.status !== 'draft')
      throw ApiError.conflict('Only draft email campaigns can be tested.');

    const { data: recipients, error: recipientsError } = await supabase
      .schema('app')
      .from('email_test_recipients')
      .select('email')
      .order('email');
    throwDatabaseError(recipientsError, 'Unable to load test recipients.');
    const emails = (recipients ?? []).map((recipient) => recipient.email);
    if (emails.length === 0)
      throw ApiError.conflict(
        'Add at least one saved test recipient before testing a campaign.',
      );

    const revision = campaignRevision(campaign, emails);
    const { data: testRun, error: testRunError } = await supabase
      .schema('app')
      .from('email_test_runs')
      .insert({
        campaign_id: campaign.id,
        revision,
        recipient_count: emails.length,
        status: 'failed',
        created_by: userId,
      })
      .select('id')
      .single();
    throwDatabaseError(testRunError, 'Unable to record the campaign test.');

    let accepted = 0;
    try {
      const config = getEmailConfig();
      const rendered = await renderCampaignEmail(
        campaign.template_key,
        campaignContent(campaign.content),
        {
          physicalAddress: config.physicalAddress,
          unsubscribeUrl: `${config.appUrl}/email-preferences`,
        },
      );
      for (const email of emails) {
        const resendEmailId = await sendDirectEmail({
          to: email,
          subject: `[TEST] ${campaign.subject}`,
          html: rendered.html,
          text: rendered.text,
          idempotencyKey: `campaign-test/${testRun.id}/${email.toLowerCase()}`,
        });
        const { error } = await supabase
          .schema('app')
          .from('email_sends')
          .insert({
            campaign_id: campaign.id,
            test_run_id: testRun.id,
            kind: 'test',
            recipient_email: email,
            resend_email_id: resendEmailId,
            last_event: 'email.sent',
            sent_at: new Date().toISOString(),
          });
        throwDatabaseError(error, 'Unable to record the test email.');
        accepted += 1;
      }
      const { error: runError } = await supabase
        .schema('app')
        .from('email_test_runs')
        .update({ accepted_count: accepted, status: 'accepted' })
        .eq('id', testRun.id);
      throwDatabaseError(runError, 'Unable to complete the campaign test.');
      const { error: campaignUpdateError } = await supabase
        .schema('app')
        .from('email_campaigns')
        .update({ last_tested_revision: revision })
        .eq('id', campaign.id);
      throwDatabaseError(
        campaignUpdateError,
        'Unable to approve the campaign test.',
      );
      return ok({
        id: testRun.id,
        recipientCount: emails.length,
        acceptedCount: accepted,
        revision,
      });
    } catch (error) {
      await supabase
        .schema('app')
        .from('email_test_runs')
        .update({ accepted_count: accepted, status: 'failed' })
        .eq('id', testRun.id);
      throw error;
    }
  } catch (error) {
    return errorResponse(error, request);
  }
}
