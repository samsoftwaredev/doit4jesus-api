import { Resend } from 'resend';

type EmailConfig = {
  apiKey: string;
  from: string;
  replyTo: string;
  physicalAddress: string;
  segmentId: string;
  appUrl: string;
};

function required(name: string) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is not configured.`);
  return value;
}

export function getEmailConfig(): EmailConfig {
  return {
    apiKey: required('RESEND_API_KEY'),
    from: required('RESEND_FROM_EMAIL'),
    replyTo: required('RESEND_REPLY_TO'),
    physicalAddress: required('RESEND_PHYSICAL_ADDRESS'),
    segmentId: required('RESEND_SEGMENT_ID'),
    appUrl: required('APP_URL').replace(/\/$/, ''),
  };
}

export function getResendClient() {
  return new Resend(getEmailConfig().apiKey);
}

export function getWebhookSecret() {
  return required('RESEND_WEBHOOK_SECRET');
}
