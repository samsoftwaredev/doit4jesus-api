import { z } from 'zod';

import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';
import { getResendClient } from '@/lib/email/config';
import { toEmailCampaign } from '@/lib/email/serializers';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ campaignId: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const campaignId = z.uuid().parse((await context.params).campaignId);
    const { supabase } = await requireAdmin(request);
    const { data: campaign, error: campaignError } = await supabase
      .schema('app')
      .from('email_campaigns')
      .select('*')
      .eq('id', campaignId)
      .single();
    throwDatabaseError(campaignError, 'Unable to load the email campaign.');
    if (campaign.status !== 'scheduled' || !campaign.resend_broadcast_id)
      throw ApiError.conflict(
        'Only scheduled email campaigns can be cancelled.',
      );

    const result = await getResendClient().broadcasts.cancel(
      campaign.resend_broadcast_id,
    );
    if (result.error)
      throw new ApiError(
        502,
        'EMAIL_PROVIDER_ERROR',
        'The email provider could not cancel this campaign.',
      );
    const { data, error } = await supabase
      .schema('app')
      .from('email_campaigns')
      .update({ status: 'cancelled', scheduled_for: null })
      .eq('id', campaign.id)
      .select('*')
      .single();
    throwDatabaseError(error, 'Unable to record the campaign cancellation.');
    return ok(toEmailCampaign(data));
  } catch (error) {
    return errorResponse(error, request);
  }
}
