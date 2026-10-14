import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { getEmailConfig } from '@/lib/email/config';
import { toEmailCampaign } from '@/lib/email/serializers';
import { renderCampaignEmail } from '@/lib/email/templates';
import {
  createEmailCampaignSchema,
  emailCampaignQuerySchema,
} from '@/lib/schemas/email';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const query = emailCampaignQuerySchema.parse(
      Object.fromEntries(new URL(request.url).searchParams.entries()),
    );
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('app')
      .from('email_campaigns')
      .select('*')
      .order('created_at', { ascending: false })
      .range(query.offset, query.offset + query.limit);
    throwDatabaseError(error, 'Unable to load email campaigns.');
    const rows = data ?? [];
    const hasMore = rows.length > query.limit;
    return ok(
      rows.slice(0, query.limit).map(toEmailCampaign),
      { headers: { 'Cache-Control': 'no-store' } },
      {
        limit: query.limit,
        offset: query.offset,
        hasMore,
        nextOffset: hasMore ? query.offset + query.limit : null,
      },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}

export async function POST(request: Request) {
  try {
    const input = createEmailCampaignSchema.parse(await readJson(request));
    const { supabase, userId } = await requireAdmin(request);
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
      .insert({
        template_key: input.templateKey,
        subject: input.subject,
        content: input.content,
        rendered_html: rendered.html,
        created_by: userId,
      })
      .select('*')
      .single();
    throwDatabaseError(error, 'Unable to create the email campaign.');
    return created(toEmailCampaign(data));
  } catch (error) {
    return errorResponse(error, request);
  }
}
