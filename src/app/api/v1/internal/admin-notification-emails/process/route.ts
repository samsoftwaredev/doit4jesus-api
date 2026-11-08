import { timingSafeEqual } from 'node:crypto';

import { errorResponse, ok } from '@/lib/api/response';
import { getEmailConfig } from '@/lib/email/config';
import { sendDirectEmail } from '@/lib/email/service';
import { renderAdminNotificationEmail } from '@/lib/email/templates';
import { createAdminClient } from '@/lib/supabase/admin';
import type { Database } from '@/lib/supabase/types';

export const dynamic = 'force-dynamic';

type Job = Database['app']['Tables']['admin_notification_email_jobs']['Row'];

function authorized(request: Request) {
  const configured = process.env.ADMIN_NOTIFICATION_WORKER_SECRET?.trim();
  const provided = request.headers
    .get('authorization')
    ?.replace(/^Bearer\s+/i, '');
  if (!configured || !provided) return false;
  const expected = Buffer.from(configured);
  const actual = Buffer.from(provided);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

function retryDelayMinutes(attempt: number) {
  return [1, 5, 15, 60, 360][Math.max(0, Math.min(attempt - 1, 4))];
}

function errorText(error: unknown) {
  return error instanceof Error
    ? error.message.slice(0, 2_000)
    : 'Unknown email delivery failure.';
}

async function markFailure(
  admin: ReturnType<typeof createAdminClient>,
  job: Job,
  error: unknown,
) {
  const exhausted = job.attempt_count >= 5;
  const availableAt = new Date(
    Date.now() + retryDelayMinutes(job.attempt_count) * 60_000,
  ).toISOString();
  const { error: updateError } = await admin
    .schema('app')
    .from('admin_notification_email_jobs')
    .update({
      status: 'failed',
      locked_at: null,
      available_at: availableAt,
      last_error: errorText(error),
    })
    .eq('id', job.id);
  if (updateError)
    throw new Error('Unable to record the admin email delivery failure.');
  return exhausted;
}

export async function POST(request: Request) {
  try {
    if (!authorized(request)) return new Response(null, { status: 401 });
    const admin = createAdminClient();
    const { data, error } = await admin
      .schema('app')
      .rpc('claim_admin_notification_email_jobs', { p_limit: 25 });
    if (error)
      throw new Error('Unable to claim admin notification email jobs.');

    let sent = 0;
    let failed = 0;
    let exhausted = 0;
    const appUrl = getEmailConfig().appUrl;

    for (const job of data ?? []) {
      try {
        const actionUrl = `${appUrl}${job.action_url}`;
        const rendered = await renderAdminNotificationEmail({
          category: job.category,
          message: job.body,
          actionUrl,
          createdAt: new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
            timeZone: 'UTC',
            timeZoneName: 'short',
          }).format(new Date(job.created_at)),
        });
        const resendEmailId = await sendDirectEmail({
          to: job.recipient_email,
          subject: job.subject,
          html: rendered.html,
          text: rendered.text,
          idempotencyKey: `admin-notification-${job.id}`,
        });
        const now = new Date().toISOString();
        const { error: sendLogError } = await admin
          .schema('app')
          .from('email_sends')
          .upsert(
            {
              admin_notification_email_job_id: job.id,
              kind: 'admin_notification',
              recipient_email: job.recipient_email,
              resend_email_id: resendEmailId,
              sent_at: now,
            },
            { onConflict: 'admin_notification_email_job_id' },
          );
        if (sendLogError)
          throw new Error(
            'Unable to record the admin notification email send.',
          );
        const { error: completionError } = await admin
          .schema('app')
          .from('admin_notification_email_jobs')
          .update({
            status: 'sent',
            locked_at: null,
            sent_at: now,
            resend_email_id: resendEmailId,
            last_error: null,
          })
          .eq('id', job.id);
        if (completionError)
          throw new Error(
            'Unable to complete the admin notification email job.',
          );
        sent += 1;
      } catch (cause) {
        failed += 1;
        if (await markFailure(admin, job, cause)) exhausted += 1;
      }
    }

    return ok({ claimed: data?.length ?? 0, sent, failed, exhausted });
  } catch (error) {
    return errorResponse(error, request);
  }
}
