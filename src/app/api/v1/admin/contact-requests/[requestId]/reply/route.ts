import { z } from 'zod';

import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import { sendDirectEmail } from '@/lib/email/service';
import { renderContactReplyEmail } from '@/lib/email/templates';
import { contactRequestReplySchema } from '@/lib/schemas/email';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ requestId: string }> };

export async function POST(request: Request, context: Context) {
  try {
    const requestId = z.uuid().parse((await context.params).requestId);
    const input = contactRequestReplySchema.parse(await readJson(request));
    const { supabase } = await requireAdmin(request);
    const { data: contact, error: contactError } = await supabase
      .schema('app')
      .from('contact_requests')
      .select('id, email')
      .eq('id', requestId)
      .single();
    throwDatabaseError(contactError, 'Unable to load the contact request.');
    const rendered = await renderContactReplyEmail(input.message);
    const resendEmailId = await sendDirectEmail({
      to: contact.email,
      subject: input.subject,
      html: rendered.html,
      text: rendered.text,
      idempotencyKey: `contact-reply/${contact.id}/${crypto.randomUUID()}`,
    });
    const { data, error } = await supabase
      .schema('app')
      .from('email_sends')
      .insert({
        contact_request_id: contact.id,
        kind: 'reply',
        recipient_email: contact.email,
        resend_email_id: resendEmailId,
        last_event: 'email.sent',
        sent_at: new Date().toISOString(),
      })
      .select('id, resend_email_id, sent_at')
      .single();
    throwDatabaseError(error, 'Unable to record the contact request reply.');
    const { error: statusError } = await supabase
      .schema('app')
      .from('contact_requests')
      .update({ status: 'done' })
      .eq('id', contact.id);
    throwDatabaseError(
      statusError,
      'Unable to update the contact request status.',
    );
    return ok({
      id: data.id,
      resendEmailId: data.resend_email_id,
      sentAt: data.sent_at,
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
