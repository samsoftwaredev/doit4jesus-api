import { ApiError } from '@/lib/api/errors';
import { errorResponse } from '@/lib/api/response';
import { getResendClient, getWebhookSecret } from '@/lib/email/config';
import { createAdminClient } from '@/lib/supabase/admin';
import type { Database } from '@/lib/supabase/types';

export const dynamic = 'force-dynamic';

type WebhookData = {
  email_id?: string;
  broadcast_id?: string;
  to?: string[];
  email?: string;
  unsubscribed?: boolean;
};

function eventUpdate(
  type: string,
  occurredAt: string,
): Database['app']['Tables']['email_sends']['Update'] {
  const update: Database['app']['Tables']['email_sends']['Update'] = {
    last_event: type,
  };
  if (type === 'email.sent') update.sent_at = occurredAt;
  if (type === 'email.delivered') update.delivered_at = occurredAt;
  if (type === 'email.opened') update.opened_at = occurredAt;
  if (type === 'email.clicked') update.clicked_at = occurredAt;
  if (type === 'email.bounced') update.bounced_at = occurredAt;
  if (type === 'email.complained') update.complained_at = occurredAt;
  if (type === 'email.suppressed') update.suppressed_at = occurredAt;
  return update;
}

function suppressionReason(type: string) {
  if (type === 'contact.updated') return 'unsubscribe';
  if (type === 'email.bounced') return 'bounce';
  if (type === 'email.complained') return 'complaint';
  return 'suppressed';
}

export async function POST(request: Request) {
  try {
    const id = request.headers.get('svix-id');
    const timestamp = request.headers.get('svix-timestamp');
    const signature = request.headers.get('svix-signature');
    if (!id || !timestamp || !signature)
      throw ApiError.badRequest('Invalid webhook signature headers.');
    const payload = await request.text();
    let event: { type: string; created_at: string; data: WebhookData };
    try {
      event = getResendClient().webhooks.verify({
        payload,
        headers: { id, timestamp, signature },
        webhookSecret: getWebhookSecret(),
      }) as typeof event;
    } catch {
      throw ApiError.badRequest('Invalid webhook signature.');
    }

    const admin = createAdminClient();
    const { error: eventError } = await admin
      .schema('app')
      .from('email_webhook_events')
      .insert({
        resend_event_id: id,
        event_type: event.type,
        resend_email_id: event.data.email_id ?? null,
        resend_broadcast_id: event.data.broadcast_id ?? null,
        occurred_at: event.created_at,
      });
    if (eventError?.code === '23505')
      return new Response(null, { status: 204 });
    if (eventError)
      throw new Error('Unable to record the email provider event.');

    const email = event.data.email ?? event.data.to?.[0];
    const shouldSuppress =
      (event.type === 'contact.updated' && event.data.unsubscribed) ||
      ['email.bounced', 'email.complained', 'email.suppressed'].includes(
        event.type,
      );
    if (email && shouldSuppress) {
      const { error } = await admin
        .schema('app')
        .from('email_suppressions')
        .upsert(
          { email, reason: suppressionReason(event.type) },
          { onConflict: 'email' },
        );
      if (error) throw new Error('Unable to update email suppression.');
    }

    if (event.data.email_id) {
      const update = eventUpdate(event.type, event.created_at);
      const { data: existing, error: existingError } = await admin
        .schema('app')
        .from('email_sends')
        .select('id')
        .eq('resend_email_id', event.data.email_id)
        .maybeSingle();
      if (existingError)
        throw new Error('Unable to load email delivery state.');
      if (existing) {
        const { error } = await admin
          .schema('app')
          .from('email_sends')
          .update(update)
          .eq('id', existing.id);
        if (error) throw new Error('Unable to update email delivery state.');
      } else if (event.data.broadcast_id && email) {
        const { data: campaign, error: campaignError } = await admin
          .schema('app')
          .from('email_campaigns')
          .select('id')
          .eq('resend_broadcast_id', event.data.broadcast_id)
          .maybeSingle();
        if (campaignError)
          throw new Error('Unable to load campaign delivery state.');
        if (campaign) {
          const { error } = await admin
            .schema('app')
            .from('email_sends')
            .insert({
              campaign_id: campaign.id,
              kind: 'campaign',
              recipient_email: email,
              resend_email_id: event.data.email_id,
              resend_broadcast_id: event.data.broadcast_id,
              ...update,
            });
          if (error)
            throw new Error('Unable to create campaign delivery state.');
        }
      }
    }
    return new Response(null, { status: 204 });
  } catch (error) {
    return errorResponse(error, request);
  }
}
