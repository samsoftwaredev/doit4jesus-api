'use client';

import Alert from '@mui/material/Alert';
import Button from '@mui/material/Button';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogTitle from '@mui/material/DialogTitle';
import Skeleton from '@mui/material/Skeleton';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';
import TextField from '@mui/material/TextField';
import ToggleButton from '@mui/material/ToggleButton';
import ToggleButtonGroup from '@mui/material/ToggleButtonGroup';
import Typography from '@mui/material/Typography';
import { useEffect, useMemo, useState } from 'react';

import type { AdminMetricKey } from '@/lib/schemas/admin-metrics';

import { adminFetch } from './adminFetch';

export type AdminMetricUser = {
  id: string;
  email: string | null;
  displayName: string | null;
  username: string | null;
  signedUpAt: string;
  lastActivityAt: string | null;
  firstActivityAt: string | null;
  activityCount: number;
  rosariesStarted: number;
  rosariesCompleted: number;
  profileSetupComplete: boolean;
  positive: boolean | null;
};

type MetricUsersResponse = {
  total: number;
  scopeTotal: number;
  positiveTotal: number;
  hasPositiveSplit: boolean;
  users: AdminMetricUser[];
};

type Filter = 'all' | 'yes' | 'no';

/** What "yes" means for each rate metric, shown as the filter label and the last column. */
const positiveLabels: Partial<
  Record<AdminMetricKey, { yes: string; no: string; column: string }>
> = {
  retention_d1: {
    yes: 'Retained',
    no: 'Not retained',
    column: 'Returned day 1',
  },
  retention_d7: {
    yes: 'Retained',
    no: 'Not retained',
    column: 'Returned day 7',
  },
  retention_d30: {
    yes: 'Retained',
    no: 'Not retained',
    column: 'Returned day 30',
  },
  signup_to_active: { yes: 'Active', no: 'Never active', column: 'Active' },
  profile_setup: {
    yes: 'Profile complete',
    no: 'Profile incomplete',
    column: 'Profile complete',
  },
  first_practice_7d: {
    yes: 'Practiced within 7 d',
    no: 'Did not',
    column: 'First practice ≤ 7 d',
  },
  churn: { yes: 'Churned', no: 'Still active', column: 'Churned' },
  rosary_completion: {
    yes: 'Completed a Rosary',
    no: 'Never completed',
    column: 'Completed a Rosary',
  },
};

const PAGE_SIZE = 50;
const dateFormatter = new Intl.DateTimeFormat('en-US', { dateStyle: 'medium' });

function formatDate(value: string | null) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : dateFormatter.format(date);
}

/** Shows the accounts behind one admin metric card: who they are and why they count. */
export default function AdminMetricUsersDialog({
  accessToken,
  metric,
  onClose,
}: {
  accessToken: string;
  metric: {
    metricKey: AdminMetricKey;
    label: string;
    description: string;
  } | null;
  onClose: () => void;
}) {
  const [filter, setFilter] = useState<Filter>('all');
  const [users, setUsers] = useState<AdminMetricUser[]>([]);
  const [summary, setSummary] = useState<Omit<MetricUsersResponse, 'users'>>();
  const [status, setStatus] = useState<'loading' | 'ready' | 'error'>(
    'loading',
  );
  const [loadingMore, setLoadingMore] = useState(false);
  const [search, setSearch] = useState('');
  const key = metric?.metricKey;

  useEffect(() => {
    setFilter('all');
    setSearch('');
  }, [key]);

  useEffect(() => {
    if (!key) return;
    let cancelled = false;
    setStatus('loading');
    adminFetch<MetricUsersResponse>(
      accessToken,
      `/api/v1/admin/app-metrics/users?metric=${key}&filter=${filter}&limit=${PAGE_SIZE}&offset=0`,
    )
      .then((body) => {
        if (cancelled || !body.data) return;
        const { users: rows, ...rest } = body.data;
        setUsers(rows);
        setSummary(rest);
        setStatus('ready');
      })
      .catch(() => {
        if (!cancelled) setStatus('error');
      });
    return () => {
      cancelled = true;
    };
  }, [accessToken, key, filter]);

  async function loadMore() {
    if (!key) return;
    setLoadingMore(true);
    try {
      const body = await adminFetch<MetricUsersResponse>(
        accessToken,
        `/api/v1/admin/app-metrics/users?metric=${key}&filter=${filter}&limit=${PAGE_SIZE}&offset=${users.length}`,
      );
      if (body.data) setUsers((current) => [...current, ...body.data!.users]);
    } catch {
      setStatus('error');
    } finally {
      setLoadingMore(false);
    }
  }

  const split = key ? positiveLabels[key] : undefined;
  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return users;
    return users.filter((user) =>
      [user.email, user.displayName, user.username].some((value) =>
        value?.toLowerCase().includes(term),
      ),
    );
  }, [search, users]);

  return (
    <Dialog
      aria-labelledby="admin-metric-users-title"
      fullWidth
      maxWidth="lg"
      onClose={onClose}
      open={metric !== null}
    >
      <DialogTitle id="admin-metric-users-title">
        {metric?.label} — users
      </DialogTitle>
      <DialogContent>
        <Stack spacing={2}>
          <Typography variant="body2" color="text.secondary">
            {metric?.description}
          </Typography>
          {summary && (
            <Typography variant="body2">
              {summary.scopeTotal.toLocaleString('en-US')} users counted
              {summary.hasPositiveSplit &&
                ` · ${summary.positiveTotal.toLocaleString('en-US')} match “${split?.yes ?? 'yes'}”`}
              {` · showing ${summary.total.toLocaleString('en-US')} in this list`}
            </Typography>
          )}
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={2}
            alignItems={{ sm: 'center' }}
          >
            {summary?.hasPositiveSplit && split && (
              <ToggleButtonGroup
                aria-label="Filter users"
                exclusive
                onChange={(_event, value: Filter | null) =>
                  value && setFilter(value)
                }
                size="small"
                value={filter}
              >
                <ToggleButton value="all">All</ToggleButton>
                <ToggleButton value="yes">{split.yes}</ToggleButton>
                <ToggleButton value="no">{split.no}</ToggleButton>
              </ToggleButtonGroup>
            )}
            <TextField
              inputProps={{ 'aria-label': 'Filter loaded users' }}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Filter loaded users by email, name or username"
              size="small"
              sx={{ flex: 1 }}
              value={search}
            />
          </Stack>

          {status === 'loading' && <Skeleton variant="rounded" height={240} />}
          {status === 'error' && (
            <Alert severity="warning">
              The users for this metric could not be loaded.
            </Alert>
          )}
          {status === 'ready' && visible.length === 0 && (
            <Alert severity="info">No users match this list.</Alert>
          )}
          {status === 'ready' && visible.length > 0 && (
            <TableContainer sx={{ maxHeight: 460 }}>
              <Table size="small" stickyHeader>
                <TableHead>
                  <TableRow>
                    <TableCell>Email</TableCell>
                    <TableCell>Name</TableCell>
                    <TableCell>Username</TableCell>
                    <TableCell>Signed up</TableCell>
                    <TableCell>Last active</TableCell>
                    <TableCell align="right">Activities</TableCell>
                    <TableCell align="right">Rosaries (done/started)</TableCell>
                    {split && <TableCell>{split.column}</TableCell>}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {visible.map((user) => (
                    <TableRow hover key={user.id}>
                      <TableCell>{user.email ?? '—'}</TableCell>
                      <TableCell>{user.displayName ?? '—'}</TableCell>
                      <TableCell>
                        {user.username ? `@${user.username}` : '—'}
                      </TableCell>
                      <TableCell>{formatDate(user.signedUpAt)}</TableCell>
                      <TableCell>{formatDate(user.lastActivityAt)}</TableCell>
                      <TableCell align="right">{user.activityCount}</TableCell>
                      <TableCell align="right">
                        {user.rosariesCompleted}/{user.rosariesStarted}
                      </TableCell>
                      {split && (
                        <TableCell>{user.positive ? 'Yes' : 'No'}</TableCell>
                      )}
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
          {status === 'ready' && summary && users.length < summary.total && (
            <Button
              disabled={loadingMore}
              onClick={() => void loadMore()}
              variant="outlined"
            >
              {loadingMore ? 'Loading…' : 'Load more'}
            </Button>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}
