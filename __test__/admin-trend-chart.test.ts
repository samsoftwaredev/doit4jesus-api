import {
  buildTrendChartData,
  getTrendDatumStyle,
  getTrendSeriesStyle,
} from '../src/components/admin/AdminTrendChart';
import type {
  AdminAppMetricsTrend,
  AdminMetricTrendSeries,
} from '../src/components/admin/adminMetricTypes';

jest.mock('react-charts', () => ({ Chart: () => null }));

const data: AdminAppMetricsTrend[] = [
  {
    date: '2026-10-01',
    signups: 0,
    newlyActiveUsers: 1,
    dailyActiveUsers: 2,
    rosariesStarted: 3,
    rosariesCompleted: 1,
  },
  {
    date: '2026-10-02',
    signups: 3,
    newlyActiveUsers: 2,
    dailyActiveUsers: 4,
    rosariesStarted: 5,
    rosariesCompleted: 3,
  },
];

const series: AdminMetricTrendSeries[] = [
  { key: 'signups', label: 'Signups', color: '#3f51b5' },
  {
    key: 'newlyActiveUsers',
    label: 'First practice',
    color: '#2e7d32',
  },
];

describe('AdminTrendChart configuration', () => {
  it('adds one matching average reference series for every observed series', () => {
    const chartData = buildTrendChartData(data, series);

    expect(chartData).toHaveLength(4);
    expect(
      chartData.map(({ id, label, color }) => ({ id, label, color })),
    ).toEqual([
      {
        id: 'observed-signups',
        label: 'Signups',
        color: '#3f51b5',
      },
      {
        id: '30-day-average-signups',
        label: 'Signups — 30-day avg: 1.5/day',
        color: '#3f51b5',
      },
      {
        id: 'observed-newlyActiveUsers',
        label: 'First practice',
        color: '#2e7d32',
      },
      {
        id: '30-day-average-newlyActiveUsers',
        label: 'First practice — 30-day avg: 1.5/day',
        color: '#2e7d32',
      },
    ]);
    expect(chartData[1]?.data.map((point) => point.value)).toEqual([1.5, 1.5]);
    expect(chartData[3]?.data.map((point) => point.value)).toEqual([1.5, 1.5]);
  });

  it('styles average series as dashed lines without datum markers', () => {
    expect(getTrendSeriesStyle('observed-signups')).toEqual({});
    expect(getTrendSeriesStyle('30-day-average-signups')).toEqual({
      line: {
        opacity: 0.75,
        strokeDasharray: '6 4',
        strokeWidth: 1.5,
      },
    });
    expect(getTrendDatumStyle('30-day-average-signups')).toEqual({
      circle: { opacity: 0 },
    });
  });
});
