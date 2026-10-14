import type { Database, Json } from '@/lib/supabase/types';

type Campaign = Database['app']['Tables']['email_campaigns']['Row'];

export function toEmailCampaign(campaign: Campaign) {
  return {
    id: campaign.id,
    templateKey: campaign.template_key,
    subject: campaign.subject,
    content: campaign.content as Json,
    status: campaign.status,
    recipientCount: campaign.recipient_count,
    scheduledFor: campaign.scheduled_for,
    sentAt: campaign.sent_at,
    lastTestedRevision: campaign.last_tested_revision,
    createdAt: campaign.created_at,
    updatedAt: campaign.updated_at,
  };
}
