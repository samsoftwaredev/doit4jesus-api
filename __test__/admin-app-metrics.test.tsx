import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import AdminAppMetrics, {
  type AdminAppMetricsData,
  getMetricStatus,
  toMetrics,
} from '../src/components/admin/AdminAppMetrics';

jest.mock('next/dynamic', () => ({
  __esModule: true,
  default: () =>
    function MockAdminTrendChart() {
      return <div data-testid="admin-trend-chart" />;
    },
}));

const metrics: AdminAppMetricsData = {
  generatedAt: '2026-10-21T12:00:00Z',
  totalUsers: 1_000,
  dailyActiveUsers: 40,
  weeklyActiveUsers: 100,
  monthlyActiveUsers: 500,
  signups7d: 50,
  signups30d: 160,
  retentionD1: 40,
  retentionD7: 20,
  retentionD30: 10,
  signupToActiveRate: 60,
  onboardingCompletionRate: 64,
  firstPracticeWithin7dRate: 50,
  churnRate: 35,
  rosaryCompletionRate: 70,
  trends: [],
};

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

describe('AdminAppMetrics', () => {
  let container: HTMLDivElement;
  let root: Root;
  let originalFetch: typeof fetch;

  beforeEach(() => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    originalFetch = global.fetch;
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: metrics }),
    }) as typeof fetch;
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(async () => {
    await act(async () => root.unmount());
    container.remove();
    global.fetch = originalFetch;
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = false;
    jest.clearAllMocks();
  });

  it('defines a target for every metric card', () => {
    expect(
      Object.fromEntries(
        toMetrics(metrics).map((metric) => [metric.label, metric.targetLabel]),
      ),
    ).toEqual({
      'Total Users': '≥ 1,000',
      DAU: '≥ 50',
      WAU: '≥ 200',
      MAU: '≥ 500',
      'Signups (7 d)': '≥ 50',
      'Signups (30 d)': '≥ 200',
      'Retention D1': '≥ 40%',
      'Retention D7': '≥ 25%',
      'Retention D30': '≥ 15%',
      'Signup → Active': '≥ 60%',
      'Profile Setup': '≥ 80%',
      'First Practice ≤ 7 d': '≥ 50%',
      'Churn Rate': '≤ 30%',
      'Rosary Completion': '≥ 70%',
    });
  });

  it('classifies higher and lower targets at their boundaries', () => {
    expect(getMetricStatus(100, 100, 'higher')).toEqual({
      label: 'On target',
      color: 'success',
    });
    expect(getMetricStatus(80, 100, 'higher')).toEqual({
      label: 'Near target',
      color: 'warning',
    });
    expect(getMetricStatus(79.9, 100, 'higher')).toEqual({
      label: 'Needs attention',
      color: 'error',
    });
    expect(getMetricStatus(30, 30, 'lower')).toEqual({
      label: 'On target',
      color: 'success',
    });
    expect(getMetricStatus(36, 30, 'lower')).toEqual({
      label: 'Near target',
      color: 'warning',
    });
    expect(getMetricStatus(36.1, 30, 'lower')).toEqual({
      label: 'Needs attention',
      color: 'error',
    });
  });

  it('renders descriptions, targets, and text statuses without explanatory tooltip controls', async () => {
    await act(async () => {
      root.render(<AdminAppMetrics accessToken="admin-token" />);
    });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });

    for (const metric of toMetrics(metrics)) {
      expect(container.textContent).toContain(metric.description);
      expect(container.textContent).toContain(`Target ${metric.targetLabel}`);
    }

    expect(container.textContent).toContain('On target');
    expect(container.textContent).toContain('Near target');
    expect(container.textContent).toContain('Needs attention');
    expect(container.textContent).toContain(
      'Compares registrations with people recording their first intentional spiritual activity.',
    );
    expect(container.textContent).toContain(
      'Trend data will appear after the administrator metrics migration is available.',
    );
    expect(container.querySelector('[aria-label^="About "]')).toBeNull();
  });

  it('labels each chart series with its 30-day daily average', async () => {
    const trends = [
      {
        date: '2026-10-20',
        signups: 0,
        newlyActiveUsers: 1,
        dailyActiveUsers: 2,
        rosariesStarted: 3,
        rosariesCompleted: 1,
      },
      {
        date: '2026-10-21',
        signups: 3,
        newlyActiveUsers: 2,
        dailyActiveUsers: 4,
        rosariesStarted: 5,
        rosariesCompleted: 3,
      },
    ];
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: { ...metrics, trends } }),
    }) as typeof fetch;

    await act(async () => {
      root.render(<AdminAppMetrics accessToken="admin-token" />);
    });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });

    expect(container.textContent).toContain('Signups — 30-day avg: 1.5/day');
    expect(container.textContent).toContain(
      'First practice — 30-day avg: 1.5/day',
    );
    expect(container.textContent).toContain(
      'Spiritually active users — 30-day avg: 3.0/day',
    );
    expect(container.textContent).toContain('Started — 30-day avg: 4.0/day');
    expect(container.textContent).toContain('Completed — 30-day avg: 2.0/day');
  });
});
