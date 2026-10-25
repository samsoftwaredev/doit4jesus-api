import type { AdminAppMetricsTrend } from '../src/components/admin/adminMetricTypes';
import {
  calculateTrendAverage,
  formatTrendAverage,
} from '../src/components/admin/adminMetricUtils';

function trendPoint(
  date: string,
  values: Partial<Omit<AdminAppMetricsTrend, 'date'>> = {},
): AdminAppMetricsTrend {
  return {
    date,
    signups: 0,
    newlyActiveUsers: 0,
    dailyActiveUsers: 0,
    rosariesStarted: 0,
    rosariesCompleted: 0,
    ...values,
  };
}

describe('admin metric trend averages', () => {
  it('includes zero-value days and preserves fractional daily averages', () => {
    const data = [
      trendPoint('2026-10-01', { signups: 0 }),
      trendPoint('2026-10-02', { signups: 2 }),
      trendPoint('2026-10-03', { signups: 3 }),
    ];

    expect(calculateTrendAverage(data, 'signups')).toBeCloseTo(5 / 3);
    expect(
      formatTrendAverage(calculateTrendAverage(data, 'signups') ?? 0),
    ).toBe('1.7');
  });

  it('returns null when there are no displayed days', () => {
    expect(calculateTrendAverage([], 'dailyActiveUsers')).toBeNull();
  });
});
