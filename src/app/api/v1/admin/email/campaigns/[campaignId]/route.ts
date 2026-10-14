import { z } from 'zod';

import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { getEmailConfig } from '@/lib/email/config';
import { toEmailCampaign } from '@/lib/email/serializers';
import { renderCampaignEmail } from '@/lib/email/templates';
import { updateEmailCampaignSchema } from '@/lib/schemas/email';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ campaignId: string }> };

export async function GET(request: Request, context: Context) {
  try {
    const campaignId = z.uuid().parse((await context.params).campaignId);
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('app')
      .from('email_campaigns')
      .select('*')
      .eq('id', campaignId)
      .single();
    throwDatabaseError(error, 'Unable to load the email campaign.');
    return ok(toEmailCampaign(data), {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function PATCH(request: Request, context: Context) {
  try {
    const campaignId = z.uuid().parse((await context.params).campaignId);
    const input = updateEmailCampaignSchema.parse(await readJson(request));
    const { supabase } = await requireAdmin(request);
    const { data: current, error: currentError } = await supabase
      .schema('app')
      .from('email_campaigns')
      .select('status')
      .eq('id', campaignId)
      .single();
    throwDatabaseError(currentError, 'Unable to load the email campaign.');
    if (current.status !== 'draft')
      throw ApiError.conflict('Only draft email campaigns can be edited.');

    const config = getEmailConfig();
    const rendered = await renderCampaignEmail(
      input.templateKey,
      input.content,
      {
        physicalAddress: config.physicalAddress,
        unsubscribeUrl: `${config.appUrl}/email-preferences`,
      },
    );
    const { data, error } = await supabase
      .schema('app')
      .from('email_campaigns')
      .update({
        template_key: input.templateKey,
        subject: input.subject,
        content: input.content,
        rendered_html: rendered.html,
        last_tested_revision: null,
      })
      .eq('id', campaignId)
      .select('*')
      .single();
    throwDatabaseError(error, 'Unable to update the email campaign.');
    return ok(toEmailCampaign(data));
  } catch (error) {
    return errorResponse(error, request);
  }
}
