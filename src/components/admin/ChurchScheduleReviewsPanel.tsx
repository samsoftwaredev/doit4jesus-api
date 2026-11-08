'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Chip from '@mui/material/Chip';
import CircularProgress from '@mui/material/CircularProgress';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogTitle from '@mui/material/DialogTitle';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { useCallback, useEffect, useRef, useState } from 'react';

const serviceTypes = ['mass', 'confession', 'adoration'] as const;
const weekdays = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const;

type ServiceType = (typeof serviceTypes)[number];
type Weekday = (typeof weekdays)[number];
type ServiceTime = {
  id?: string;
  serviceType: ServiceType;
  weekday: Weekday;
  startTime: string;
  endTime: string | null;
};
type Church = {
  id: string;
  name: string;
  address: {
    line1: string;
    line2: string | null;
    city: string;
    regionName: string | null;
    postalCode: string | null;
    countryCode: string;
  };
  timezone: string;
  latitude: number | null;
  longitude: number | null;
  scheduleVerifiedAt: string | null;
};
type Review = {
  id: string;
  status: 'pending' | 'completed';
  outcome: 'verified' | 'closed' | null;
  reviewReason: 'missing_schedule' | 'stale_schedule';
  church: Church;
  subscriberCount: number;
  schedule: ServiceTime[];
  createdAt: string;
  completedAt: string | null;
};
type ApiResponse<T> = {
  data?: T;
  meta?: { hasMore?: boolean };
  error?: { message?: string };
};

function formatDate(value: string | null) {
  if (!value) return 'Never';
  const date = new Date(value);
  return Number.isNaN(date.valueOf())
    ? value
    : new Intl.DateTimeFormat('en-US', {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(date);
}

async function adminFetch<T>(
  token: string,
  url: string,
  init: RequestInit = {},
) {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  });
  const body = (await response.json()) as ApiResponse<T>;
  if (!response.ok)
    throw new AdminFetchError(
      response.status,
      body.error?.message ?? 'The request could not be completed.',
    );
  return body;
}

class AdminFetchError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'AdminFetchError';
  }
}

function completionLabel(review: Review) {
  return review.outcome ? `Completed · ${review.outcome}` : 'Completed';
}

function initialRows(review: Review): ServiceTime[] {
  const rows = review.schedule.map((item) => ({ ...item }));
  for (const serviceType of serviceTypes) {
    if (!rows.some((item) => item.serviceType === serviceType)) {
      rows.push({
        serviceType,
        weekday: 'sunday',
        startTime: '',
        endTime: null,
      });
    }
  }
  return rows;
}

export default function ChurchScheduleReviewsPanel({
  token,
  onClose,
}: {
  token: string;
  onClose: () => void;
}) {
  const [items, setItems] = useState<Review[]>([]);
  const [status, setStatus] = useState('pending');
  const [offset, setOffset] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<Review | null>(null);
  const [serviceTimes, setServiceTimes] = useState<ServiceTime[]>([]);
  const [church, setChurch] = useState<Church | null>(null);
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const readOnly = selected?.status === 'completed';
  // Lets a load ignore its response when a newer load (e.g. a quick filter
  // change) has started since, so stale results never overwrite fresh ones.
  const latestLoad = useRef(0);

  const load = useCallback(
    async (nextOffset = offset) => {
      const loadId = ++latestLoad.current;
      setLoading(true);
      setError('');
      try {
        const response = await adminFetch<Review[]>(
          token,
          `/api/v1/admin/church-schedule-reviews?status=${status}&limit=20&offset=${nextOffset}`,
        );
        if (loadId !== latestLoad.current) return;
        setItems(response.data ?? []);
        setHasMore(Boolean(response.meta?.hasMore));
        setOffset(nextOffset);
      } catch (cause) {
        if (loadId !== latestLoad.current) return;
        setError(
          cause instanceof Error
            ? cause.message
            : 'Unable to load church schedule reviews.',
        );
      } finally {
        if (loadId === latestLoad.current) setLoading(false);
      }
    },
    [offset, status, token],
  );

  // Reload from the first page whenever the status filter changes (and on mount).
  useEffect(() => {
    void load(0);
  }, [status]);

  function openReview(review: Review) {
    setSelected(review);
    setServiceTimes(initialRows(review));
    setChurch({ ...review.church, address: { ...review.church.address } });
    setReason('');
    setError('');
  }

  function updateServiceTime(index: number, patch: Partial<ServiceTime>) {
    setServiceTimes((current) =>
      current.map((item, itemIndex) =>
        itemIndex === index ? { ...item, ...patch } : item,
      ),
    );
  }

  async function submit(decision: 'verified' | 'closed') {
    if (!selected || !church || readOnly) return;
    if (decision === 'closed' && !reason.trim()) {
      setError('A reason is required when marking a church closed.');
      return;
    }
    if (
      decision === 'verified' &&
      (serviceTypes.some(
        (serviceType) =>
          !serviceTimes.some((item) => item.serviceType === serviceType),
      ) ||
        serviceTimes.some((item) => !/^\d{2}:\d{2}$/.test(item.startTime)))
    ) {
      setError('Enter a valid time for Mass, confession, and adoration.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      const payload =
        decision === 'closed'
          ? { decision, reason: reason.trim() }
          : {
              decision,
              reason: reason.trim() || null,
              church: {
                name: church.name,
                addressLine1: church.address.line1,
                addressLine2: church.address.line2,
                city: church.address.city,
                regionName: church.address.regionName,
                postalCode: church.address.postalCode,
                countryCode: church.address.countryCode,
                timezone: church.timezone,
                ...(church.latitude === null
                  ? {}
                  : { latitude: church.latitude }),
                ...(church.longitude === null
                  ? {}
                  : { longitude: church.longitude }),
              },
              serviceTimes: serviceTimes.map(
                ({ serviceType, weekday, startTime, endTime }) => ({
                  serviceType,
                  weekday,
                  startTime,
                  endTime: endTime || null,
                }),
              ),
            };
      await adminFetch(
        token,
        `/api/v1/admin/church-schedule-reviews/${selected.id}`,
        {
          method: 'PATCH',
          body: JSON.stringify(payload),
        },
      );
      setSelected(null);
      await load(offset);
    } catch (cause) {
      if (cause instanceof AdminFetchError && cause.status === 409) {
        // Someone (or an earlier submit) already completed this review.
        setSelected({ ...selected, status: 'completed' });
        // load() clears the error on start, so refresh first, then explain.
        await load(offset);
        setError(
          'This review has already been completed, so it can no longer be changed. The list has been refreshed.',
        );
        return;
      }
      setError(
        cause instanceof Error
          ? cause.message
          : 'Unable to review the church schedule.',
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Box component="section" mt={3}>
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        justifyContent="space-between"
        spacing={1}
        mb={2}
      >
        <Typography component="h2" variant="h5" fontWeight={700}>
          Church Schedule Reviews
        </Typography>
        <Button onClick={onClose}>Return to analytics</Button>
      </Stack>
      <Stack spacing={2}>
        <Alert severity="info">
          Every verified schedule must include at least one Mass, confession,
          and Eucharistic adoration time.
        </Alert>
        <Stack direction="row" spacing={1}>
          <TextField
            select
            label="Status"
            value={status}
            onChange={(event) => setStatus(event.target.value)}
            sx={{ minWidth: 180 }}
          >
            {['pending', 'completed', 'all'].map((value) => (
              <MenuItem key={value} value={value}>
                {value}
              </MenuItem>
            ))}
          </TextField>
        </Stack>
        {error && !selected && <Alert severity="error">{error}</Alert>}
        {loading ? (
          <Stack alignItems="center" py={5}>
            <CircularProgress aria-label="Loading schedule reviews" />
          </Stack>
        ) : items.length === 0 ? (
          <Alert severity="info">
            No church schedule reviews match this filter.
          </Alert>
        ) : (
          <Stack spacing={1}>
            {items.map((item) => (
              <Card key={item.id} variant="outlined">
                <CardContent>
                  <Stack
                    direction={{ xs: 'column', md: 'row' }}
                    justifyContent="space-between"
                    spacing={1}
                  >
                    <Box>
                      <Typography fontWeight={700}>
                        {item.church.name}
                      </Typography>
                      <Typography variant="body2">
                        {item.church.address.line1}, {item.church.address.city}
                        {item.church.address.regionName
                          ? `, ${item.church.address.regionName}`
                          : ''}
                      </Typography>
                      <Typography
                        variant="caption"
                        color="text.secondary"
                        component="div"
                      >
                        {item.reviewReason === 'stale_schedule'
                          ? 'Six-month reverification'
                          : 'Missing schedule'}{' '}
                        · {item.subscriberCount} subscriber
                        {item.subscriberCount === 1 ? '' : 's'} · requested{' '}
                        {formatDate(item.createdAt)}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        Last verified:{' '}
                        {formatDate(item.church.scheduleVerifiedAt)}
                      </Typography>
                    </Box>
                    <Stack
                      direction="row"
                      spacing={1}
                      alignItems="center"
                      alignSelf={{ xs: 'flex-start', md: 'center' }}
                    >
                      {item.status === 'completed' && (
                        <Chip
                          size="small"
                          color={
                            item.outcome === 'closed' ? 'default' : 'success'
                          }
                          label={completionLabel(item)}
                        />
                      )}
                      <Button onClick={() => openReview(item)}>
                        {item.status === 'completed'
                          ? 'View review'
                          : 'Review schedule'}
                      </Button>
                    </Stack>
                  </Stack>
                </CardContent>
              </Card>
            ))}
            <Stack direction="row" spacing={1} justifyContent="flex-end">
              <Button
                disabled={offset === 0}
                onClick={() => void load(Math.max(0, offset - 20))}
              >
                Previous
              </Button>
              <Button
                disabled={!hasMore}
                onClick={() => void load(offset + 20)}
              >
                Next
              </Button>
            </Stack>
          </Stack>
        )}
      </Stack>
      {selected && church && (
        <Dialog
          open
          fullWidth
          maxWidth="lg"
          onClose={submitting ? undefined : () => setSelected(null)}
        >
          <DialogTitle>
            <Stack direction="row" spacing={1} alignItems="center">
              <span>
                {readOnly ? '' : 'Review '}
                {selected.church.name}
              </span>
              {readOnly && (
                <Chip
                  size="small"
                  color={selected.outcome === 'closed' ? 'default' : 'success'}
                  label={completionLabel(selected)}
                />
              )}
            </Stack>
          </DialogTitle>
          <DialogContent dividers>
            <Stack spacing={2}>
              {error && (
                <Alert severity={readOnly ? 'warning' : 'error'}>{error}</Alert>
              )}
              {readOnly && !error && (
                <Alert severity="info">
                  This review was completed
                  {selected.completedAt
                    ? ` on ${formatDate(selected.completedAt)}`
                    : ''}{' '}
                  and is read-only.
                </Alert>
              )}
              <Typography variant="h6">Church details</Typography>
              <Box
                display="grid"
                gridTemplateColumns={{ xs: '1fr', md: 'repeat(2, 1fr)' }}
                gap={1.5}
              >
                <TextField
                  disabled={readOnly}
                  label="Name"
                  value={church.name}
                  onChange={(event) =>
                    setChurch({ ...church, name: event.target.value })
                  }
                />
                <TextField
                  disabled={readOnly}
                  label="Address"
                  value={church.address.line1}
                  onChange={(event) =>
                    setChurch({
                      ...church,
                      address: { ...church.address, line1: event.target.value },
                    })
                  }
                />
                <TextField
                  disabled={readOnly}
                  label="Address line 2"
                  value={church.address.line2 ?? ''}
                  onChange={(event) =>
                    setChurch({
                      ...church,
                      address: {
                        ...church.address,
                        line2: event.target.value || null,
                      },
                    })
                  }
                />
                <TextField
                  disabled={readOnly}
                  label="City"
                  value={church.address.city}
                  onChange={(event) =>
                    setChurch({
                      ...church,
                      address: { ...church.address, city: event.target.value },
                    })
                  }
                />
                <TextField
                  disabled={readOnly}
                  label="State/region"
                  value={church.address.regionName ?? ''}
                  onChange={(event) =>
                    setChurch({
                      ...church,
                      address: {
                        ...church.address,
                        regionName: event.target.value || null,
                      },
                    })
                  }
                />
                <TextField
                  disabled={readOnly}
                  label="Postal code"
                  value={church.address.postalCode ?? ''}
                  onChange={(event) =>
                    setChurch({
                      ...church,
                      address: {
                        ...church.address,
                        postalCode: event.target.value || null,
                      },
                    })
                  }
                />
                <TextField
                  disabled={readOnly}
                  label="Country code"
                  value={church.address.countryCode}
                  onChange={(event) =>
                    setChurch({
                      ...church,
                      address: {
                        ...church.address,
                        countryCode: event.target.value.toUpperCase(),
                      },
                    })
                  }
                />
                <TextField
                  disabled={readOnly}
                  label="Timezone"
                  value={church.timezone}
                  onChange={(event) =>
                    setChurch({ ...church, timezone: event.target.value })
                  }
                />
              </Box>
              <Typography variant="h6">
                Mass, confession, and adoration times
              </Typography>
              {serviceTimes.map((item, index) => (
                <Box
                  key={`${index}-${item.id ?? 'new'}`}
                  display="grid"
                  gridTemplateColumns={{
                    xs: '1fr',
                    md: '2fr 2fr 1.5fr 1.5fr auto',
                  }}
                  gap={1}
                  alignItems="center"
                >
                  <TextField
                    disabled={readOnly}
                    select
                    label="Service"
                    value={item.serviceType}
                    onChange={(event) =>
                      updateServiceTime(index, {
                        serviceType: event.target.value as ServiceType,
                      })
                    }
                  >
                    {serviceTypes.map((value) => (
                      <MenuItem key={value} value={value}>
                        {value}
                      </MenuItem>
                    ))}
                  </TextField>
                  <TextField
                    disabled={readOnly}
                    select
                    label="Weekday"
                    value={item.weekday}
                    onChange={(event) =>
                      updateServiceTime(index, {
                        weekday: event.target.value as Weekday,
                      })
                    }
                  >
                    {weekdays.map((value) => (
                      <MenuItem key={value} value={value}>
                        {value}
                      </MenuItem>
                    ))}
                  </TextField>
                  <TextField
                    disabled={readOnly}
                    label="Start"
                    type="time"
                    slotProps={{ inputLabel: { shrink: true } }}
                    value={item.startTime}
                    onChange={(event) =>
                      updateServiceTime(index, {
                        startTime: event.target.value,
                      })
                    }
                  />
                  <TextField
                    disabled={readOnly}
                    label="End (optional)"
                    type="time"
                    slotProps={{ inputLabel: { shrink: true } }}
                    value={item.endTime ?? ''}
                    onChange={(event) =>
                      updateServiceTime(index, {
                        endTime: event.target.value || null,
                      })
                    }
                  />
                  <Button
                    color="error"
                    disabled={readOnly || serviceTimes.length <= 3}
                    onClick={() =>
                      setServiceTimes((current) =>
                        current.filter((_, itemIndex) => itemIndex !== index),
                      )
                    }
                  >
                    Remove
                  </Button>
                </Box>
              ))}
              <Button
                variant="outlined"
                disabled={readOnly}
                onClick={() =>
                  setServiceTimes((current) => [
                    ...current,
                    {
                      serviceType: 'mass',
                      weekday: 'sunday',
                      startTime: '',
                      endTime: null,
                    },
                  ])
                }
              >
                Add service time
              </Button>
              <TextField
                disabled={readOnly}
                label="Review notes / closure reason"
                multiline
                minRows={2}
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                inputProps={{ maxLength: 2000 }}
              />
            </Stack>
          </DialogContent>
          <DialogActions>
            {!readOnly && (
              <>
                <Button
                  disabled={submitting}
                  color="error"
                  onClick={() => void submit('closed')}
                >
                  Mark church closed
                </Button>
                <Button
                  disabled={submitting}
                  variant="contained"
                  onClick={() => void submit('verified')}
                >
                  Verify schedule
                </Button>
              </>
            )}
            <Button disabled={submitting} onClick={() => setSelected(null)}>
              {readOnly ? 'Close' : 'Cancel'}
            </Button>
          </DialogActions>
        </Dialog>
      )}
    </Box>
  );
}
