import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';

export const dynamic = 'force-dynamic';

type Send = {
  campaign_id: string | null;
  kind: 'campaign' | 'test' | 'reply';
  sent_at: string | null;
  delivered_at: string | null;
  opened_at: string | null;
  clicked_at: string | null;
  bounced_at: string | null;
  complained_at: string | null;
  suppressed_at: string | null;
};

function metrics(rows: Send[]) {
  const sent = rows.filter((row) => row.sent_at).length;
  const delivered = rows.filter((row) => row.delivered_at).length;
  const opened = rows.filter((row) => row.opened_at).length;
  const clicked = rows.filter((row) => row.clicked_at).length;
  const bounced = rows.filter((row) => row.bounced_at).length;
  const complained = rows.filter((row) => row.complained_at).length;
  const suppressed = rows.filter((row) => row.suppressed_at).length;
  return {
    sent,
    delivered,
    opened,
    clicked,
    bounced,
    complained,
    suppressed,
    openRate: delivered ? Number(((opened / delivered) * 100).toFixed(1)) : 0,
    clickRate: delivered ? Number(((clicked / delivered) * 100).toFixed(1)) : 0,
  };
}

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);
    const [
      { data: sends, error: sendsError },
      { data: campaigns, error: campaignsError },
    ] = await Promise.all([
      supabase
        .schema('app')
        .from('email_sends')
        .select(
          'campaign_id, kind, sent_at, delivered_at, opened_at, clicked_at, bounced_at, complained_at, suppressed_at',
        ),
      supabase
        .schema('app')
        .from('email_campaigns')
        .select(
          'id, subject, template_key, status, recipient_count, sent_at, scheduled_for',
        )
        .order('created_at', { ascending: false })
        .limit(50),
    ]);
    throwDatabaseError(sendsError, 'Unable to load email analytics.');
    throwDatabaseError(campaignsError, 'Unable to load email campaigns.');
    const campaignSends = (sends ?? []).filter(
      (send) => send.kind === 'campaign',
    ) as Send[];
    return ok(
      {
        overall: metrics(
          (sends ?? []).filter((send) => send.kind !== 'test') as Send[],
        ),
        campaigns: (campaigns ?? []).map((campaign) => ({
          id: campaign.id,
          subject: campaign.subject,
          templateKey: campaign.template_key,
          status: campaign.status,
          recipientCount: campaign.recipient_count,
          sentAt: campaign.sent_at,
          scheduledFor: campaign.scheduled_for,
          metrics: metrics(
            campaignSends.filter((send) => send.campaign_id === campaign.id),
          ),
        })),
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
