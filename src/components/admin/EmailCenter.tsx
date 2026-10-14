'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import CircularProgress from '@mui/material/CircularProgress';
import Divider from '@mui/material/Divider';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { useCallback, useEffect, useMemo, useState } from 'react';

type ApiResponse<T> = { data?: T; error?: { message?: string } };
type Campaign = {
  id: string;
  templateKey: 'update' | 'announcement';
  subject: string;
  content: CampaignContent;
  status: 'draft' | 'scheduled' | 'sent' | 'cancelled' | 'failed';
  recipientCount: number;
  scheduledFor: string | null;
  sentAt: string | null;
};
type CampaignContent = {
  previewText: string;
  heading: string;
  body: string;
  ctaLabel?: string;
  ctaUrl?: string;
};
type TestRecipient = { id: string; email: string; createdAt: string };
type Metrics = {
  sent: number;
  delivered: number;
  opened: number;
  clicked: number;
  bounced: number;
  complained: number;
  suppressed: number;
  openRate: number;
  clickRate: number;
};
type Analytics = {
  overall: Metrics;
  campaigns: Array<Campaign & { metrics: Metrics }>;
};

const blankContent: CampaignContent = {
  previewText: '',
  heading: '',
  body: '',
  ctaLabel: '',
  ctaUrl: '',
};

async function emailFetch<T>(
  token: string,
  url: string,
  init: RequestInit = {},
) {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  });
  const body =
    response.status === 204 ? {} : ((await response.json()) as ApiResponse<T>);
  if (!response.ok)
    throw new Error(
      body.error?.message ?? 'The email request could not be completed.',
    );
  return body;
}

function formatDate(value: string | null) {
  return value
    ? new Intl.DateTimeFormat('en-US', {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(new Date(value))
    : '—';
}

function Metric({ label, value }: { label: string; value: number | string }) {
  return (
    <Box>
      <Typography variant="caption" color="text.secondary">
        {label}
      </Typography>
      <Typography fontWeight={700}>{value}</Typography>
    </Box>
  );
}

export default function EmailCenter({ token }: { token: string }) {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [testRecipients, setTestRecipients] = useState<TestRecipient[]>([]);
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [working, setWorking] = useState<string | null>(null);
  const [newTestEmail, setNewTestEmail] = useState('');
  const [templateKey, setTemplateKey] = useState<'update' | 'announcement'>(
    'update',
  );
  const [subject, setSubject] = useState('');
  const [content, setContent] = useState<CampaignContent>(blankContent);
  const [schedule, setSchedule] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [campaignResponse, recipientResponse, analyticsResponse] =
        await Promise.all([
          emailFetch<Campaign[]>(
            token,
            '/api/v1/admin/email/campaigns?limit=50&offset=0',
          ),
          emailFetch<TestRecipient[]>(
            token,
            '/api/v1/admin/email/test-recipients?limit=100&offset=0',
          ),
          emailFetch<Analytics>(token, '/api/v1/admin/email/analytics'),
        ]);
      setCampaigns(campaignResponse.data ?? []);
      setTestRecipients(recipientResponse.data ?? []);
      setAnalytics(analyticsResponse.data ?? null);
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : 'Unable to load the Email Center.',
      );
    } finally {
      setLoading(false);
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  const preview = useMemo(
    () => ({
      heading: content.heading || 'Your email heading',
      body: content.body || 'Your campaign message will appear here.',
    }),
    [content],
  );

  async function addTestRecipient() {
    setWorking('test-recipient');
    try {
      await emailFetch(token, '/api/v1/admin/email/test-recipients', {
        method: 'POST',
        body: JSON.stringify({ email: newTestEmail }),
      });
      setNewTestEmail('');
      await load();
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : 'Unable to add the test recipient.',
      );
    } finally {
      setWorking(null);
    }
  }

  async function removeTestRecipient(id: string) {
    setWorking(id);
    try {
      await emailFetch(token, `/api/v1/admin/email/test-recipients/${id}`, {
        method: 'DELETE',
      });
      await load();
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : 'Unable to remove the test recipient.',
      );
    } finally {
      setWorking(null);
    }
  }

  async function createCampaign() {
    setWorking('create');
    try {
      await emailFetch(token, '/api/v1/admin/email/campaigns', {
        method: 'POST',
        body: JSON.stringify({ templateKey, subject, content }),
      });
      setSubject('');
      setContent(blankContent);
      setSchedule('');
      await load();
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : 'Unable to create the campaign.',
      );
    } finally {
      setWorking(null);
    }
  }

  async function campaignAction(
    campaign: Campaign,
    action: 'test' | 'send' | 'cancel',
  ) {
    const key = `${action}-${campaign.id}`;
    setWorking(key);
    try {
      if (action === 'test') {
        await emailFetch(
          token,
          `/api/v1/admin/email/campaigns/${campaign.id}/test`,
          { method: 'POST' },
        );
      } else if (action === 'send') {
        const scheduledFor = schedule
          ? new Date(schedule).toISOString()
          : undefined;
        await emailFetch(
          token,
          `/api/v1/admin/email/campaigns/${campaign.id}/send`,
          {
            method: 'POST',
            body: JSON.stringify(scheduledFor ? { scheduledFor } : {}),
          },
        );
      } else {
        await emailFetch(
          token,
          `/api/v1/admin/email/campaigns/${campaign.id}/cancel`,
          { method: 'POST' },
        );
      }
      await load();
    } catch (nextError) {
      setError(
        nextError instanceof Error
          ? nextError.message
          : 'Unable to update the campaign.',
      );
    } finally {
      setWorking(null);
    }
  }

  return (
    <Stack spacing={3}>
      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {loading && (
        <Stack alignItems="center" py={5}>
          <CircularProgress aria-label="Loading Email Center" />
        </Stack>
      )}
      {!loading && (
        <>
          <Alert severity="info">
            Campaigns send to active app accounts with existing consent. A
            successful test to every saved test recipient is required before
            launch.
          </Alert>
          <Box
            display="grid"
            gridTemplateColumns={{ xs: '1fr', md: '1.2fr 0.8fr' }}
            gap={2}
          >
            <Card variant="outlined">
              <CardContent>
                <Stack spacing={1.5}>
                  <Typography variant="h6" fontWeight={700}>
                    Create campaign draft
                  </Typography>
                  <TextField
                    select
                    label="Template"
                    value={templateKey}
                    onChange={(event) =>
                      setTemplateKey(
                        event.target.value as 'update' | 'announcement',
                      )
                    }
                  >
                    <MenuItem value="update">General update</MenuItem>
                    <MenuItem value="announcement">Announcement</MenuItem>
                  </TextField>
                  <TextField
                    label="Subject"
                    value={subject}
                    onChange={(event) => setSubject(event.target.value)}
                    inputProps={{ maxLength: 160 }}
                  />
                  <TextField
                    label="Preview text"
                    value={content.previewText}
                    onChange={(event) =>
                      setContent({
                        ...content,
                        previewText: event.target.value,
                      })
                    }
                    inputProps={{ maxLength: 180 }}
                  />
                  <TextField
                    label="Heading"
                    value={content.heading}
                    onChange={(event) =>
                      setContent({ ...content, heading: event.target.value })
                    }
                    inputProps={{ maxLength: 140 }}
                  />
                  <TextField
                    label="Message"
                    value={content.body}
                    onChange={(event) =>
                      setContent({ ...content, body: event.target.value })
                    }
                    multiline
                    minRows={5}
                    inputProps={{ maxLength: 10_000 }}
                  />
                  <Box
                    display="grid"
                    gridTemplateColumns={{ xs: '1fr', sm: '1fr 1fr' }}
                    gap={1.5}
                  >
                    <TextField
                      label="CTA label (optional)"
                      value={content.ctaLabel}
                      onChange={(event) =>
                        setContent({ ...content, ctaLabel: event.target.value })
                      }
                    />
                    <TextField
                      label="CTA URL (optional)"
                      value={content.ctaUrl}
                      onChange={(event) =>
                        setContent({ ...content, ctaUrl: event.target.value })
                      }
                    />
                  </Box>
                  <Button
                    variant="contained"
                    disabled={working === 'create'}
                    onClick={() => void createCampaign()}
                  >
                    Create draft
                  </Button>
                </Stack>
              </CardContent>
            </Card>
            <Card variant="outlined">
              <CardContent>
                <Stack spacing={1.5}>
                  <Typography variant="h6" fontWeight={700}>
                    Template preview
                  </Typography>
                  <Typography variant="caption" color="primary">
                    DO IT 4 JESUS · {templateKey.toUpperCase()}
                  </Typography>
                  <Typography variant="h5">{preview.heading}</Typography>
                  <Typography whiteSpace="pre-wrap">{preview.body}</Typography>
                  {content.ctaLabel && (
                    <Button variant="contained" disabled>
                      {content.ctaLabel}
                    </Button>
                  )}
                  <Divider />
                  <Typography variant="caption" color="text.secondary">
                    The source-controlled template adds your configured mailing
                    address and unsubscribe footer.
                  </Typography>
                </Stack>
              </CardContent>
            </Card>
          </Box>
          <Card variant="outlined">
            <CardContent>
              <Stack spacing={1.5}>
                <Typography variant="h6" fontWeight={700}>
                  Saved test recipients
                </Typography>
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
                  <TextField
                    fullWidth
                    type="email"
                    label="Test email"
                    value={newTestEmail}
                    onChange={(event) => setNewTestEmail(event.target.value)}
                  />
                  <Button
                    variant="outlined"
                    disabled={!newTestEmail || working === 'test-recipient'}
                    onClick={() => void addTestRecipient()}
                  >
                    Add
                  </Button>
                </Stack>
                {testRecipients.length === 0 ? (
                  <Typography color="text.secondary">
                    Add one or more recipients before testing a campaign.
                  </Typography>
                ) : (
                  testRecipients.map((recipient) => (
                    <Stack
                      key={recipient.id}
                      direction="row"
                      justifyContent="space-between"
                      alignItems="center"
                    >
                      <Typography>{recipient.email}</Typography>
                      <Button
                        color="error"
                        disabled={working === recipient.id}
                        onClick={() => void removeTestRecipient(recipient.id)}
                      >
                        Remove
                      </Button>
                    </Stack>
                  ))
                )}
              </Stack>
            </CardContent>
          </Card>
          <Card variant="outlined">
            <CardContent>
              <Stack spacing={1.5}>
                <Typography variant="h6" fontWeight={700}>
                  Campaign drafts and launches
                </Typography>
                <TextField
                  label="Optional schedule (America/Chicago)"
                  type="datetime-local"
                  value={schedule}
                  onChange={(event) => setSchedule(event.target.value)}
                  slotProps={{ inputLabel: { shrink: true } }}
                  helperText="Leave empty to send immediately after testing."
                />
                {campaigns.length === 0 ? (
                  <Typography color="text.secondary">
                    No campaign drafts yet.
                  </Typography>
                ) : (
                  campaigns.map((campaign) => (
                    <Card key={campaign.id} variant="outlined">
                      <CardContent>
                        <Stack spacing={1}>
                          <Typography fontWeight={700}>
                            {campaign.subject}
                          </Typography>
                          <Typography variant="body2" color="text.secondary">
                            {campaign.templateKey} · {campaign.status} ·{' '}
                            {campaign.recipientCount} recipients
                          </Typography>
                          <Typography variant="caption">
                            Scheduled: {formatDate(campaign.scheduledFor)} ·
                            Sent: {formatDate(campaign.sentAt)}
                          </Typography>
                          <Stack direction="row" spacing={1} flexWrap="wrap">
                            {campaign.status === 'draft' && (
                              <>
                                <Button
                                  disabled={working === `test-${campaign.id}`}
                                  onClick={() =>
                                    void campaignAction(campaign, 'test')
                                  }
                                >
                                  Send test
                                </Button>
                                <Button
                                  variant="contained"
                                  disabled={working === `send-${campaign.id}`}
                                  onClick={() =>
                                    void campaignAction(campaign, 'send')
                                  }
                                >
                                  {schedule ? 'Schedule' : 'Send now'}
                                </Button>
                              </>
                            )}
                            {campaign.status === 'scheduled' && (
                              <Button
                                color="error"
                                disabled={working === `cancel-${campaign.id}`}
                                onClick={() =>
                                  void campaignAction(campaign, 'cancel')
                                }
                              >
                                Cancel schedule
                              </Button>
                            )}
                          </Stack>
                        </Stack>
                      </CardContent>
                    </Card>
                  ))
                )}
              </Stack>
            </CardContent>
          </Card>
          {analytics && (
            <Card variant="outlined">
              <CardContent>
                <Stack spacing={1.5}>
                  <Typography variant="h6" fontWeight={700}>
                    Email analytics
                  </Typography>
                  <Box
                    display="grid"
                    gridTemplateColumns="repeat(auto-fit, minmax(100px, 1fr))"
                    gap={1}
                  >
                    <Metric label="Sent" value={analytics.overall.sent} />
                    <Metric
                      label="Delivered"
                      value={analytics.overall.delivered}
                    />
                    <Metric
                      label="Opened"
                      value={`${analytics.overall.openRate}%`}
                    />
                    <Metric
                      label="Clicked"
                      value={`${analytics.overall.clickRate}%`}
                    />
                    <Metric label="Bounced" value={analytics.overall.bounced} />
                    <Metric
                      label="Complaints"
                      value={analytics.overall.complained}
                    />
                  </Box>
                </Stack>
              </CardContent>
            </Card>
          )}
        </>
      )}
    </Stack>
  );
}
