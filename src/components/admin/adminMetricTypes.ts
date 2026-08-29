export type AdminAppMetricsTrend = {
  date: string;
  signups: number;
  newlyActiveUsers: number;
  dailyActiveUsers: number;
  rosariesStarted: number;
  rosariesCompleted: number;
};

export type AdminMetricTrendSeries = {
  key: Exclude<keyof AdminAppMetricsTrend, 'date'>;
  label: string;
  color: string;
};
