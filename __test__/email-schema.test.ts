import {
  campaignContentSchema,
  createEmailCampaignSchema,
  scheduleEmailCampaignSchema,
} from '../src/lib/schemas/email';

describe('email campaign schemas', () => {
  const content = {
    previewText: 'This week in prayer',
    heading: 'Pray with us',
    body: 'Thank you for being part of the community.',
  };

  it('accepts a supported campaign template and text-only content', () => {
    expect(
      createEmailCampaignSchema.parse({
        templateKey: 'update',
        subject: 'A weekly update',
        content,
      }),
    ).toEqual({ templateKey: 'update', subject: 'A weekly update', content });
  });

  it('requires a CTA label and URL together', () => {
    expect(() =>
      campaignContentSchema.parse({ ...content, ctaLabel: 'Open the app' }),
    ).toThrow();
    expect(() =>
      campaignContentSchema.parse({
        ...content,
        ctaUrl: 'https://example.com',
      }),
    ).toThrow();
  });

  it('requires a future schedule value to be valid ISO date-time input', () => {
    expect(scheduleEmailCampaignSchema.parse({})).toEqual({});
    expect(() =>
      scheduleEmailCampaignSchema.parse({ scheduledFor: 'tomorrow' }),
    ).toThrow();
  });
});
