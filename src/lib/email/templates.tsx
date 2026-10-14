import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Preview,
  Section,
  Text,
} from '@react-email/components';
import { render } from '@react-email/render';
import { createElement } from 'react';

import type { CampaignContent, CampaignTemplateKey } from '@/lib/schemas/email';

const brand = '#4b2e83';
const background = '#f7f5fa';

function paragraphs(value: string) {
  return value.split(/\n{2,}/).map((paragraph) => paragraph.trim());
}

function CampaignEmail({
  content,
  templateKey,
  physicalAddress,
  unsubscribeUrl,
}: {
  content: CampaignContent;
  templateKey: CampaignTemplateKey;
  physicalAddress: string;
  unsubscribeUrl: string;
}) {
  const label = templateKey === 'announcement' ? 'Announcement' : 'Update';
  return (
    <Html lang="en">
      <Head />
      <Preview>{content.previewText}</Preview>
      <Body
        style={{ backgroundColor: background, fontFamily: 'Arial, sans-serif' }}
      >
        <Container
          style={{
            backgroundColor: '#ffffff',
            margin: '24px auto',
            maxWidth: '600px',
            padding: '32px',
          }}
        >
          <Text
            style={{
              color: brand,
              fontSize: '13px',
              fontWeight: 700,
              letterSpacing: '1px',
              margin: '0 0 8px',
            }}
          >
            DO IT 4 JESUS · {label.toUpperCase()}
          </Text>
          <Heading
            style={{
              color: '#1f1b24',
              fontSize: '28px',
              lineHeight: '36px',
              margin: '0 0 20px',
            }}
          >
            {content.heading}
          </Heading>
          {paragraphs(content.body).map((paragraph, index) => (
            <Text
              key={index}
              style={{ color: '#38313f', fontSize: '16px', lineHeight: '24px' }}
            >
              {paragraph}
            </Text>
          ))}
          {content.ctaLabel && content.ctaUrl && (
            <Section style={{ margin: '28px 0' }}>
              <Button
                href={content.ctaUrl}
                style={{
                  backgroundColor: brand,
                  borderRadius: '4px',
                  boxSizing: 'border-box',
                  color: '#ffffff',
                  display: 'inline-block',
                  padding: '12px 18px',
                  textDecoration: 'none',
                }}
              >
                {content.ctaLabel}
              </Button>
            </Section>
          )}
          <Hr
            style={{
              borderColor: '#ded9e5',
              borderStyle: 'solid',
              margin: '28px 0 18px',
            }}
          />
          <Text
            style={{
              color: '#6d6574',
              fontSize: '12px',
              lineHeight: '18px',
              margin: 0,
            }}
          >
            {physicalAddress}
          </Text>
          <Text
            style={{ color: '#6d6574', fontSize: '12px', lineHeight: '18px' }}
          >
            <a href={unsubscribeUrl}>Unsubscribe from these updates</a>
          </Text>
        </Container>
      </Body>
    </Html>
  );
}

function ContactReplyEmail({ message }: { message: string }) {
  return (
    <Html lang="en">
      <Head />
      <Preview>A response from Do It 4 Jesus</Preview>
      <Body
        style={{ backgroundColor: background, fontFamily: 'Arial, sans-serif' }}
      >
        <Container
          style={{
            backgroundColor: '#ffffff',
            margin: '24px auto',
            maxWidth: '600px',
            padding: '32px',
          }}
        >
          <Heading
            style={{
              color: '#1f1b24',
              fontSize: '24px',
              lineHeight: '32px',
              margin: '0 0 20px',
            }}
          >
            A response from Do It 4 Jesus
          </Heading>
          {paragraphs(message).map((paragraph, index) => (
            <Text
              key={index}
              style={{ color: '#38313f', fontSize: '16px', lineHeight: '24px' }}
            >
              {paragraph}
            </Text>
          ))}
        </Container>
      </Body>
    </Html>
  );
}

export const emailTemplateRegistry = {
  update: { label: 'General update' },
  announcement: { label: 'Announcement' },
  'contact-reply': { label: 'Contact request reply' },
} as const;

export async function renderCampaignEmail(
  templateKey: CampaignTemplateKey,
  content: CampaignContent,
  options: { physicalAddress: string; unsubscribeUrl: string },
) {
  const node = createElement(CampaignEmail, {
    content,
    templateKey,
    physicalAddress: options.physicalAddress,
    unsubscribeUrl: options.unsubscribeUrl,
  });
  const [html, text] = await Promise.all([
    render(node),
    render(node, { plainText: true }),
  ]);
  return { html, text };
}

export async function renderContactReplyEmail(message: string) {
  const node = createElement(ContactReplyEmail, { message });
  const [html, text] = await Promise.all([
    render(node),
    render(node, { plainText: true }),
  ]);
  return { html, text };
}
