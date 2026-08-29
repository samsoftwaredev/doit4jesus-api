'use client';

import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import IconButton from '@mui/material/IconButton';
import Paper from '@mui/material/Paper';
import Skeleton from '@mui/material/Skeleton';
import Stack from '@mui/material/Stack';
import Tooltip from '@mui/material/Tooltip';
import Typography from '@mui/material/Typography';
import dynamic from 'next/dynamic';
import { useEffect, useState } from 'react';

import type {
  AdminAppMetricsTrend,
  AdminMetricTrendSeries,
} from './adminMetricTypes';

type AdminAppMetricsData = {
  generatedAt: string;
  totalUsers: number;
  dailyActiveUsers: number;
  weeklyActiveUsers: number;
  monthlyActiveUsers: number;
  signups7d: number;
  signups30d: number;
  retentionD1: number;
  retentionD7: number;
  retentionD30: number;
  signupToActiveRate: number;
  onboardingCompletionRate: number;
  firstPracticeWithin7dRate: number;
  churnRate: number;
  rosaryCompletionRate: number;
  trends: AdminAppMetricsTrend[];
};

type LoadState =
  | { status: 'loading' }
  | { status: 'ready'; metrics: AdminAppMetricsData }
  | { status: 'unavailable' }
  | { status: 'error' };

type Metric = {
  label: string;
  value: string;
  description: string;
};

const numberFormatter = new Intl.NumberFormat('en-US');
const AdminTrendChart = dynamic(() => import('./AdminTrendChart'), {
  ssr: false,
  loading: () => <Skeleton variant="rounded" height={280} />,
});

function formatPercent(value: number | undefined) {
  return typeof value === 'number' && Number.isFinite(value)
    ? `${value.toFixed(1)}%`
    : '—';
}

function formatNumber(value: number | undefined) {
  return typeof value === 'number' && Number.isFinite(value)
    ? numberFormatter.format(value)
    : '—';
}

function MetricCard({ label, value, description }: Metric) {
  return (
    <Paper variant="outlined" sx={{ p: 2, minWidth: 0 }}>
      <Stack direction="row" spacing={0.5} alignItems="center">
        <Typography variant="body2" color="text.secondary" noWrap>
          {label}
        </Typography>
        <Tooltip title={description} arrow>
          <IconButton
            aria-label={`About ${label}`}
            size="small"
            sx={{ ml: 'auto', p: 0.25 }}
          >
            <InfoOutlinedIcon fontSize="inherit" />
          </IconButton>
        </Tooltip>
      </Stack>
      <Typography variant="h4" fontWeight={700} mt={1}>
        {value}
      </Typography>
    </Paper>
  );
}

function normalizeTrends(value: unknown): AdminAppMetricsTrend[] {
  if (!Array.isArray(value)) return [];

  const trends: AdminAppMetricsTrend[] = [];

  for (const point of value) {
    if (
      typeof point !== 'object' ||
      point === null ||
      typeof point.date !== 'string'
    ) {
      continue;
    }

    const toNumber = (value: unknown) =>
      typeof value === 'number' && Number.isFinite(value) ? value : 0;

    trends.push({
      date: point.date,
      signups: toNumber(point.signups),
      newlyActiveUsers: toNumber(point.newlyActiveUsers),
      dailyActiveUsers: toNumber(point.dailyActiveUsers),
      rosariesStarted: toNumber(point.rosariesStarted),
      rosariesCompleted: toNumber(point.rosariesCompleted),
    });
  }

  return trends;
}

function TrendChart({
  title,
  description,
  data,
  series,
}: {
  title: string;
  description: string;
  data?: AdminAppMetricsTrend[];
  series: AdminMetricTrendSeries[];
}) {
  const chartData = normalizeTrends(data);
  if (chartData.length === 0) {
    return (
      <Paper component="figure" variant="outlined" sx={{ m: 0, p: 2.5 }}>
        <Stack spacing={1}>
          <Stack direction="row" spacing={0.5} alignItems="center">
            <Typography component="figcaption" variant="h6" fontWeight={700}>
              {title}
            </Typography>
            <Tooltip title={description} arrow>
              <IconButton
                aria-label={`About ${title}`}
                size="small"
                sx={{ p: 0.25 }}
              >
                <InfoOutlinedIcon fontSize="inherit" />
              </IconButton>
            </Tooltip>
          </Stack>
          <Typography variant="body2" color="text.secondary">
            Trend data will appear after the administrator metrics migration is
            available.
          </Typography>
        </Stack>
      </Paper>
    );
  }

  return (
    <Paper component="figure" variant="outlined" sx={{ m: 0, p: 2.5 }}>
      <Stack spacing={1.5}>
        <Box component="figcaption">
          <Stack direction="row" spacing={0.5} alignItems="center">
            <Typography variant="h6" fontWeight={700}>
              {title}
            </Typography>
            <Tooltip title={description} arrow>
              <IconButton
                aria-label={`About ${title}`}
                size="small"
                sx={{ p: 0.25 }}
              >
                <InfoOutlinedIcon fontSize="inherit" />
              </IconButton>
            </Tooltip>
          </Stack>
          <Typography variant="body2" color="text.secondary">
            Last 30 calendar days. {description}
          </Typography>
        </Box>

        <AdminTrendChart data={chartData} series={series} />

        <Stack direction="row" spacing={2} useFlexGap flexWrap="wrap">
          {series.map((item) => (
            <Stack
              key={item.key}
              direction="row"
              spacing={0.75}
              alignItems="center"
            >
              <Box
                aria-hidden
                sx={{
                  width: 12,
                  height: 3,
                  borderRadius: 1,
                  bgcolor: item.color,
                }}
              />
              <Typography variant="caption" color="text.secondary">
                {item.label}
              </Typography>
            </Stack>
          ))}
        </Stack>
      </Stack>
    </Paper>
  );
}

function MetricsSkeleton() {
  return (
    <Box
      display="grid"
      gridTemplateColumns="repeat(auto-fit, minmax(180px, 1fr))"
      gap={2}
    >
      {Array.from({ length: 14 }, (_, index) => (
        <Paper key={index} variant="outlined" sx={{ p: 2 }}>
          <Skeleton width="55%" />
          <Skeleton width="42%" height={46} />
        </Paper>
      ))}
    </Box>
  );
}

function toMetrics(metrics: AdminAppMetricsData): Metric[] {
  return [
    {
      label: 'Total Users',
      value: formatNumber(metrics.totalUsers),
      description: 'All registered accounts that have not been deleted.',
    },
    {
      label: 'DAU',
      value: formatNumber(metrics.dailyActiveUsers),
      description:
        'Unique users who recorded a verified or self-reported spiritual activity in the last 24 hours.',
    },
    {
      label: 'WAU',
      value: formatNumber(metrics.weeklyActiveUsers),
      description:
        'Unique users who recorded a verified or self-reported spiritual activity in the last 7 days.',
    },
    {
      label: 'MAU',
      value: formatNumber(metrics.monthlyActiveUsers),
      description:
        'Unique users who recorded a verified or self-reported spiritual activity in the last 30 days.',
    },
    {
      label: 'Signups (7 d)',
      value: formatNumber(metrics.signups7d),
      description: 'New, non-deleted accounts registered in the past 7 days.',
    },
    {
      label: 'Signups (30 d)',
      value: formatNumber(metrics.signups30d),
      description: 'New, non-deleted accounts registered in the past 30 days.',
    },
    {
      label: 'Retention D1',
      value: formatPercent(metrics.retentionD1),
      description:
        'Eligible users who recorded an activity between 1 and 2 days after signing up.',
    },
    {
      label: 'Retention D7',
      value: formatPercent(metrics.retentionD7),
      description:
        'Eligible users who recorded an activity between 7 and 8 days after signing up.',
    },
    {
      label: 'Retention D30',
      value: formatPercent(metrics.retentionD30),
      description:
        'Eligible users who recorded an activity between 30 and 31 days after signing up.',
    },
    {
      label: 'Signup → Active',
      value: formatPercent(metrics.signupToActiveRate),
      description:
        'Registered accounts that have recorded at least one verified or self-reported spiritual activity.',
    },
    {
      label: 'Profile Setup',
      value: formatPercent(metrics.onboardingCompletionRate),
      description:
        'Accounts whose profile has been marked complete after required onboarding details were saved.',
    },
    {
      label: 'First Practice ≤ 7 d',
      value: formatPercent(metrics.firstPracticeWithin7dRate),
      description:
        'Eligible new accounts that recorded their first verified or self-reported spiritual activity within 7 days of signup.',
    },
    {
      label: 'Churn Rate',
      value: formatPercent(metrics.churnRate),
      description:
        'Accounts at least 30 days old that have not recorded a spiritual activity in the past 30 days.',
    },
    {
      label: 'Rosary Completion',
      value: formatPercent(metrics.rosaryCompletionRate),
      description:
        'Rosary activity records with a completion timestamp, divided by all valid Rosary activity records.',
    },
  ];
}

export default function AdminAppMetrics({
  accessToken,
}: {
  accessToken: string;
}) {
  const [state, setState] = useState<LoadState>({ status: 'loading' });
  const [refreshCount, setRefreshCount] = useState(0);

  useEffect(() => {
    const controller = new AbortController();

    async function loadMetrics() {
      try {
        const response = await fetch('/api/v1/admin/app-metrics', {
          headers: { Authorization: `Bearer ${accessToken}` },
          signal: controller.signal,
        });
        if (response.status === 401 || response.status === 403) {
          setState({ status: 'unavailable' });
          return;
        }
        if (!response.ok)
          throw new Error('Unable to load administrator metrics.');

        const body = (await response.json()) as { data?: AdminAppMetricsData };
        if (!body.data || typeof body.data !== 'object') {
          throw new Error('Invalid administrator metrics response.');
        }

        setState({
          status: 'ready',
          metrics: {
            ...body.data,
            trends: normalizeTrends(body.data.trends),
          },
        });
      } catch (error) {
        if (controller.signal.aborted) return;
        setState({ status: 'error' });
      }
    }

    void loadMetrics();
    return () => controller.abort();
  }, [accessToken, refreshCount]);

  if (state.status === 'unavailable') {
    return (
      <Alert severity="warning" sx={{ mt: 3 }}>
        Administrator access is required to view app analytics.
      </Alert>
    );
  }

  return (
    <Paper
      component="section"
      aria-labelledby="admin-app-metrics-title"
      sx={{ mt: 3, p: 3 }}
    >
      <Stack spacing={2}>
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          spacing={1.5}
          justifyContent="space-between"
          alignItems={{ sm: 'center' }}
        >
          <Box>
            <Typography
              id="admin-app-metrics-title"
              variant="h5"
              fontWeight={700}
            >
              Admin App Metrics
            </Typography>
            <Typography variant="body2" color="text.secondary" mt={0.5}>
              Track whether people are returning to prayer—not whether they are
              winning the game.
            </Typography>
          </Box>
          <Button
            disabled={state.status === 'loading'}
            onClick={() => {
              setState({ status: 'loading' });
              setRefreshCount((count) => count + 1);
            }}
            variant="outlined"
          >
            Refresh metrics
          </Button>
        </Stack>

        <Alert severity="info">
          <Typography variant="subtitle2" fontWeight={700}>
            North Star: weekly spiritually active users
          </Typography>
          <Typography variant="body2">
            Unique users who return and complete at least one intentional
            spiritual activity in a week.
          </Typography>
        </Alert>

        {state.status === 'loading' && <MetricsSkeleton />}
        {state.status === 'error' && (
          <Alert severity="warning">
            Administrator metrics are currently unavailable.
          </Alert>
        )}
        {state.status === 'ready' && (
          <Stack spacing={2}>
            <Box
              display="grid"
              gridTemplateColumns="repeat(auto-fit, minmax(180px, 1fr))"
              gap={2}
            >
              {toMetrics(state.metrics).map((metric) => (
                <MetricCard key={metric.label} {...metric} />
              ))}
            </Box>

            <Box
              display="grid"
              gridTemplateColumns="repeat(auto-fit, minmax(min(100%, 420px), 1fr))"
              gap={2}
            >
              <TrendChart
                data={state.metrics.trends}
                description="Compares registrations with people recording their first intentional spiritual activity. This shows whether new users are reaching value."
                series={[
                  { key: 'signups', label: 'Signups', color: '#3f51b5' },
                  {
                    key: 'newlyActiveUsers',
                    label: 'First practice',
                    color: '#2e7d32',
                  },
                ]}
                title="Growth & Activation"
              />
              <TrendChart
                data={state.metrics.trends}
                description="Unique people who recorded a verified or self-reported spiritual activity each day."
                series={[
                  {
                    key: 'dailyActiveUsers',
                    label: 'Spiritually active users',
                    color: '#6a1b9a',
                  },
                ]}
                title="Daily Spiritual Activity"
              />
              <TrendChart
                data={state.metrics.trends}
                description="Accepted Rosary activity records started and completed each day. A completion is dated when the Rosary was completed."
                series={[
                  {
                    key: 'rosariesStarted',
                    label: 'Started',
                    color: '#b26a00',
                  },
                  {
                    key: 'rosariesCompleted',
                    label: 'Completed',
                    color: '#2e7d32',
                  },
                ]}
                title="Rosary Practice"
              />
            </Box>
          </Stack>
        )}
      </Stack>
    </Paper>
  );
}
