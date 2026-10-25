'use client';

import Box from '@mui/material/Box';
import { useMemo } from 'react';
import {
  type AxisOptions,
  Chart,
  type DatumStyles,
  type SeriesStyles,
  type UserSerie,
} from 'react-charts';

import type {
  AdminAppMetricsTrend,
  AdminMetricTrendSeries,
} from './adminMetricTypes';
import { calculateTrendAverage, formatTrendAverage } from './adminMetricUtils';

export type ChartDatum = {
  date: Date;
  value: number;
};

const numberFormatter = new Intl.NumberFormat('en-US');

function toChartDate(date: string) {
  return new Date(`${date}T00:00:00Z`);
}

const averageSeriesPrefix = '30-day-average-';

export function isAverageSeries(seriesId: string | undefined) {
  return seriesId?.startsWith(averageSeriesPrefix) ?? false;
}

export function getTrendSeriesStyle(
  seriesId: string | undefined,
): SeriesStyles {
  if (!isAverageSeries(seriesId)) return {};

  return {
    line: {
      opacity: 0.75,
      strokeDasharray: '6 4',
      strokeWidth: 1.5,
    },
  };
}

export function getTrendDatumStyle(seriesId: string | undefined): DatumStyles {
  return isAverageSeries(seriesId) ? { circle: { opacity: 0 } } : {};
}

export function buildTrendChartData(
  data: AdminAppMetricsTrend[],
  series: AdminMetricTrendSeries[],
): UserSerie<ChartDatum>[] {
  return series.flatMap((item) => {
    const average = calculateTrendAverage(data, item.key) ?? 0;
    const points = data.map((point) => ({
      date: toChartDate(point.date),
      value: point[item.key],
    }));
    const averagePoints = data.map((point) => ({
      date: toChartDate(point.date),
      value: average,
    }));

    return [
      {
        id: `observed-${item.key}`,
        label: item.label,
        color: item.color,
        data: points,
      },
      {
        id: `${averageSeriesPrefix}${item.key}`,
        label: `${item.label} — 30-day avg: ${formatTrendAverage(average)}/day`,
        color: item.color,
        data: averagePoints,
      },
    ];
  });
}

export default function AdminTrendChart({
  data,
  series,
}: {
  data: AdminAppMetricsTrend[];
  series: AdminMetricTrendSeries[];
}) {
  const chartData = useMemo(
    () => buildTrendChartData(data, series),
    [data, series],
  );
  const primaryAxis = useMemo<AxisOptions<ChartDatum>>(
    () => ({
      getValue: (datum) => datum.date,
      scaleType: 'time',
      formatters: {
        scale: (value: Date) =>
          new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC',
          }).format(value),
      },
      showGrid: false,
    }),
    [],
  );
  const secondaryAxes = useMemo<AxisOptions<ChartDatum>[]>(
    () => [
      {
        getValue: (datum) => datum.value,
        elementType: 'line',
        formatters: {
          scale: (value: number) => numberFormatter.format(value),
        },
        position: 'left',
        showDatumElements: 'onFocus',
      },
    ],
    [],
  );
  const options = useMemo(
    () => ({
      data: chartData,
      primaryAxis,
      secondaryAxes,
      defaultColors: series.flatMap((item) => [item.color, item.color]),
      getSeriesStyle: (chartSeries: {
        originalSeries: UserSerie<ChartDatum>;
      }) => getTrendSeriesStyle(chartSeries.originalSeries.id),
      getDatumStyle: (datum: { originalSeries: UserSerie<ChartDatum> }) =>
        getTrendDatumStyle(datum.originalSeries.id),
      interactionMode: 'primary' as const,
      tooltip: true,
    }),
    [chartData, primaryAxis, secondaryAxes, series],
  );

  return (
    <Box sx={{ height: 280, minWidth: 0 }}>
      <Chart options={options} />
    </Box>
  );
}
