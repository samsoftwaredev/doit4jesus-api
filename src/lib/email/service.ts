import type { SupabaseClient } from '@supabase/supabase-js';
import { createHash } from 'node:crypto';

import { ApiError } from '@/lib/api/errors';
import { getEmailConfig, getResendClient } from '@/lib/email/config';
import type { CampaignContent, CampaignTemplateKey } from '@/lib/schemas/email';
import type { Database, Json } from '@/lib/supabase/types';

type CampaignRow = Database['app']['Tables']['email_campaigns']['Row'];

function resendFailure(message: string): never {
  throw new ApiError(502, 'EMAIL_PROVIDER_ERROR', message);
}

export function campaignRevision(
  campaign: Pick<CampaignRow, 'template_key' | 'subject' | 'content'>,
  recipients: string[],
) {
  return createHash('sha256')
    .update(
      JSON.stringify({
        templateKey: campaign.template_key,
        subject: campaign.subject,
        content: campaign.content,
        recipients: recipients.map((email) => email.toLowerCase()).sort(),
      }),
    )
    .digest('hex');
}

export function campaignContent(value: Json): CampaignContent {
  return value as CampaignContent;
}

export async function syncCampaignSegment(admin: SupabaseClient<Database>) {
  const config = getEmailConfig();
  const resend = getResendClient();
  const { data: users, error: usersError } = await admin
    .schema('app')
    .from('users')
    .select('email')
    .eq('status', 'active')
    .is('deleted_at', null)
    .not('email', 'is', null);

  if (usersError)
    throw new ApiError(
      500,
      'DATABASE_ERROR',
      'Unable to load campaign recipients.',
    );

  const { data: suppressions, error: suppressionsError } = await admin
    .schema('app')
    .from('email_suppressions')
    .select('email');
  if (suppressionsError)
    throw new ApiError(
      500,
      'DATABASE_ERROR',
      'Unable to load email suppressions.',
    );

  const blocked = new Set(
    (suppressions ?? []).map((item) => item.email.toLowerCase()),
  );
  const recipients = (users ?? [])
    .map((user) => user.email)
    .filter(
      (email): email is string =>
        Boolean(email) && !blocked.has(email.toLowerCase()),
    );

  for (const email of recipients) {
    const created = await resend.contacts.create({
      email,
      unsubscribed: false,
      segments: [{ id: config.segmentId }],
    });
    if (created.error) {
      // Existing contacts are expected. Adding the segment is idempotent from
      // the application perspective; Resend retains its unsubscribe state.
      const assigned = await resend.contacts.segments.add({
        email,
        segmentId: config.segmentId,
      });
      if (assigned.error && assigned.error.name !== 'validation_error') {
        resendFailure(
          'Unable to synchronize campaign recipients with the email provider.',
        );
      }
    }
  }

  return recipients;
}

export async function sendDirectEmail(input: {
  to: string;
  subject: string;
  html: string;
  text: string;
  idempotencyKey: string;
}) {
  const config = getEmailConfig();
  const result = await getResendClient().emails.send(
    {
      from: config.from,
      to: input.to,
      subject: input.subject,
      html: input.html,
      text: input.text,
      replyTo: config.replyTo,
    },
    { idempotencyKey: input.idempotencyKey },
  );
  const data = result.data;
  if (result.error || !data)
    resendFailure('The email provider could not accept this message.');
  return data.id;
}

export async function createCampaignBroadcast(input: {
  campaign: CampaignRow;
  scheduledFor?: string;
}) {
  const config = getEmailConfig();
  const content = campaignContent(input.campaign.content);
  const result = await getResendClient().broadcasts.create({
    segmentId: config.segmentId,
    from: config.from,
    replyTo: config.replyTo,
    subject: input.campaign.subject,
    html: input.campaign.rendered_html,
    text: content.body,
    previewText: content.previewText,
    name: `${input.campaign.template_key}-${input.campaign.id}`,
    send: true,
    ...(input.scheduledFor ? { scheduledAt: input.scheduledFor } : {}),
  });
  const data = result.data;
  if (result.error || !data)
    resendFailure('The email provider could not create this campaign.');
  return data.id;
}
