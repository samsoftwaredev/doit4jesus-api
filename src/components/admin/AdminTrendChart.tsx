'use client';

import Box from '@mui/material/Box';
import { useMemo } from 'react';
import { type AxisOptions, Chart } from 'react-charts';

import type {
  AdminAppMetricsTrend,
  AdminMetricTrendSeries,
} from './adminMetricTypes';

type ChartDatum = {
  date: Date;
  value: number;
};

const numberFormatter = new Intl.NumberFormat('en-US');

function toChartDate(date: string) {
  return new Date(`${date}T00:00:00Z`);
}

export default function AdminTrendChart({
  data,
  series,
}: {
  data: AdminAppMetricsTrend[];
  series: AdminMetricTrendSeries[];
}) {
  const chartData = useMemo(
    () =>
      series.map((item) => ({
        label: item.label,
        data: data.map((point) => ({
          date: toChartDate(point.date),
          value: point[item.key],
        })),
      })),
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
      defaultColors: series.map((item) => item.color),
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
