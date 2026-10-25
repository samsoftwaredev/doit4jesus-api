import type {
  AdminAppMetricsTrend,
  AdminMetricTrendSeries,
} from './adminMetricTypes';

export function calculateTrendAverage(
  data: AdminAppMetricsTrend[],
  key: AdminMetricTrendSeries['key'],
) {
  if (data.length === 0) return null;

  return data.reduce((total, point) => total + point[key], 0) / data.length;
}

export function formatTrendAverage(value: number) {
  return value.toFixed(1);
}
