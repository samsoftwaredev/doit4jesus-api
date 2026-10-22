'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Chip from '@mui/material/Chip';
import Paper from '@mui/material/Paper';
import Skeleton from '@mui/material/Skeleton';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import dynamic from 'next/dynamic';
import { useEffect, useState } from 'react';

import type {
  AdminAppMetricsTrend,
  AdminMetricTrendSeries,
} from './adminMetricTypes';

export type AdminAppMetricsData = {
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

type MetricDirection = 'higher' | 'lower';

export type Metric = {
  label: string;
  rawValue: number;
  value: string;
  description: string;
  target: number;
  targetLabel: string;
  direction: MetricDirection;
};

type MetricStatus = {
  label: 'On target' | 'Near target' | 'Needs attention';
  color: 'success' | 'warning' | 'error';
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

export function getMetricStatus(
  value: number,
  target: number,
  direction: MetricDirection,
): MetricStatus {
  if (direction === 'lower') {
    if (value <= target) return { label: 'On target', color: 'success' };
    if (value <= target * 1.2)
      return { label: 'Near target', color: 'warning' };
    return { label: 'Needs attention', color: 'error' };
  }

  if (value >= target) return { label: 'On target', color: 'success' };
  if (value >= target * 0.8) return { label: 'Near target', color: 'warning' };
  return { label: 'Needs attention', color: 'error' };
}

function MetricCard({
  label,
  rawValue,
  value,
  description,
  target,
  targetLabel,
  direction,
}: Metric) {
  const status = getMetricStatus(rawValue, target, direction);

  return (
    <Paper
      variant="outlined"
      sx={{ display: 'flex', height: '100%', minWidth: 0, p: 2 }}
    >
      <Stack spacing={1.25} width="100%">
        <Typography variant="body2" color="text.secondary">
          {label}
        </Typography>
        <Typography variant="h4" fontWeight={700}>
          {value}
        </Typography>
        <Stack
          direction="row"
          spacing={1}
          alignItems="center"
          justifyContent="space-between"
          useFlexGap
          flexWrap="wrap"
        >
          <Typography variant="caption" color="text.secondary">
            Target {targetLabel}
          </Typography>
          <Chip
            color={status.color}
            label={status.label}
            size="small"
            variant="outlined"
          />
        </Stack>
        <Typography variant="body2" color="text.secondary">
          {description}
        </Typography>
      </Stack>
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
          <Box component="figcaption">
            <Typography variant="h6" fontWeight={700}>
              {title}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {description}
            </Typography>
          </Box>
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
          <Typography variant="h6" fontWeight={700}>
            {title}
          </Typography>
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
      gridTemplateColumns="repeat(auto-fit, minmax(min(100%, 240px), 1fr))"
      gap={2}
    >
      {Array.from({ length: 14 }, (_, index) => (
        <Paper key={index} variant="outlined" sx={{ p: 2 }}>
          <Skeleton width="55%" />
          <Skeleton width="42%" height={46} />
          <Skeleton width="75%" />
          <Skeleton height={40} />
        </Paper>
      ))}
    </Box>
  );
}

export function toMetrics(metrics: AdminAppMetricsData): Metric[] {
  return [
    {
      label: 'Total Users',
      rawValue: metrics.totalUsers,
      value: formatNumber(metrics.totalUsers),
      description: 'All registered accounts that have not been deleted.',
      target: 1_000,
      targetLabel: '≥ 1,000',
      direction: 'higher',
    },
    {
      label: 'DAU',
      rawValue: metrics.dailyActiveUsers,
      value: formatNumber(metrics.dailyActiveUsers),
      description:
        'Unique users who recorded a verified or self-reported spiritual activity in the last 24 hours.',
      target: 50,
      targetLabel: '≥ 50',
      direction: 'higher',
    },
    {
      label: 'WAU',
      rawValue: metrics.weeklyActiveUsers,
      value: formatNumber(metrics.weeklyActiveUsers),
      description:
        'Unique users who recorded a verified or self-reported spiritual activity in the last 7 days.',
      target: 200,
      targetLabel: '≥ 200',
      direction: 'higher',
    },
    {
      label: 'MAU',
      rawValue: metrics.monthlyActiveUsers,
      value: formatNumber(metrics.monthlyActiveUsers),
      description:
        'Unique users who recorded a verified or self-reported spiritual activity in the last 30 days.',
      target: 500,
      targetLabel: '≥ 500',
      direction: 'higher',
    },
    {
      label: 'Signups (7 d)',
      rawValue: metrics.signups7d,
      value: formatNumber(metrics.signups7d),
      description: 'New, non-deleted accounts registered in the past 7 days.',
      target: 50,
      targetLabel: '≥ 50',
      direction: 'higher',
    },
    {
      label: 'Signups (30 d)',
      rawValue: metrics.signups30d,
      value: formatNumber(metrics.signups30d),
      description: 'New, non-deleted accounts registered in the past 30 days.',
      target: 200,
      targetLabel: '≥ 200',
      direction: 'higher',
    },
    {
      label: 'Retention D1',
      rawValue: metrics.retentionD1,
      value: formatPercent(metrics.retentionD1),
      description:
        'Eligible users who recorded an activity between 1 and 2 days after signing up.',
      target: 40,
      targetLabel: '≥ 40%',
      direction: 'higher',
    },
    {
      label: 'Retention D7',
      rawValue: metrics.retentionD7,
      value: formatPercent(metrics.retentionD7),
      description:
        'Eligible users who recorded an activity between 7 and 8 days after signing up.',
      target: 25,
      targetLabel: '≥ 25%',
      direction: 'higher',
    },
    {
      label: 'Retention D30',
      rawValue: metrics.retentionD30,
      value: formatPercent(metrics.retentionD30),
      description:
        'Eligible users who recorded an activity between 30 and 31 days after signing up.',
      target: 15,
      targetLabel: '≥ 15%',
      direction: 'higher',
    },
    {
      label: 'Signup → Active',
      rawValue: metrics.signupToActiveRate,
      value: formatPercent(metrics.signupToActiveRate),
      description:
        'Registered accounts that have recorded at least one verified or self-reported spiritual activity.',
      target: 60,
      targetLabel: '≥ 60%',
      direction: 'higher',
    },
    {
      label: 'Profile Setup',
      rawValue: metrics.onboardingCompletionRate,
      value: formatPercent(metrics.onboardingCompletionRate),
      description:
        'Accounts whose profile has been marked complete after required onboarding details were saved.',
      target: 80,
      targetLabel: '≥ 80%',
      direction: 'higher',
    },
    {
      label: 'First Practice ≤ 7 d',
      rawValue: metrics.firstPracticeWithin7dRate,
      value: formatPercent(metrics.firstPracticeWithin7dRate),
      description:
        'Eligible new accounts that recorded their first verified or self-reported spiritual activity within 7 days of signup.',
      target: 50,
      targetLabel: '≥ 50%',
      direction: 'higher',
    },
    {
      label: 'Churn Rate',
      rawValue: metrics.churnRate,
      value: formatPercent(metrics.churnRate),
      description:
        'Accounts at least 30 days old that have not recorded a spiritual activity in the past 30 days.',
      target: 30,
      targetLabel: '≤ 30%',
      direction: 'lower',
    },
    {
      label: 'Rosary Completion',
      rawValue: metrics.rosaryCompletionRate,
      value: formatPercent(metrics.rosaryCompletionRate),
      description:
        'Rosary activity records with a completion timestamp, divided by all valid Rosary activity records.',
      target: 70,
      targetLabel: '≥ 70%',
      direction: 'higher',
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
              gridTemplateColumns="repeat(auto-fit, minmax(min(100%, 240px), 1fr))"
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
