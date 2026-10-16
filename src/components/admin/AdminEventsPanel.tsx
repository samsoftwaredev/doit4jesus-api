'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Checkbox from '@mui/material/Checkbox';
import Chip from '@mui/material/Chip';
import Divider from '@mui/material/Divider';
import FormControlLabel from '@mui/material/FormControlLabel';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { useCallback, useEffect, useMemo, useState } from 'react';
import ReactMarkdown from 'react-markdown';

type Meta = { hasMore?: boolean; nextOffset?: number | null };
type ApiResponse<T> = { data?: T; meta?: Meta; error?: { message?: string } };
type EventStatus = 'pending' | 'active' | 'inactive' | 'rejected';
type Audience =
  | 'all'
  | 'kids'
  | 'youth'
  | 'men'
  | 'women'
  | 'single'
  | 'married';
type Country = {
  code: string;
  name: string;
};
type Location = {
  name: string;
  addressLine1: string;
  addressLine2: string | null;
  city: string;
  regionName: string | null;
  postalCode: string | null;
  countryCode: string;
};
type AdminEvent = {
  id: string;
  creatorId: string | null;
  title: string;
  description: string;
  imageUrl: string | null;
  eventUrl: string | null;
  eventType: 'online' | 'physical';
  onlineUrl: string | null;
  location: Location | null;
  timezone: string;
  startsAt: string;
  endsAt: string;
  lifespanDays: number;
  audiences: Audience[];
  status: EventStatus;
  approvedAt: string | null;
  expiresAt: string | null;
  createdAt: string;
  reviewedBy: string | null;
  reviewedAt: string | null;
  attendeeCount: number;
  viewCount: number;
};
type EventDraft = {
  title: string;
  description: string;
  imageUrl: string;
  eventUrl: string;
  eventType: 'online' | 'physical';
  onlineUrl: string;
  locationName: string;
  addressLine1: string;
  addressLine2: string;
  city: string;
  regionName: string;
  postalCode: string;
  countryCode: string;
  timezone: string;
  startsAt: string;
  endsAt: string;
  lifespanDays: number;
  audiences: Audience[];
};

const audienceValues: Audience[] = [
  'all',
  'kids',
  'youth',
  'men',
  'women',
  'single',
  'married',
];
const statusValues: (EventStatus | 'all')[] = [
  'pending',
  'active',
  'inactive',
  'rejected',
  'all',
];

function browserTimezone() {
  return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
}

function blankDraft(): EventDraft {
  return {
    title: '',
    description: '',
    imageUrl: '',
    eventUrl: '',
    eventType: 'online',
    onlineUrl: '',
    locationName: '',
    addressLine1: '',
    addressLine2: '',
    city: '',
    regionName: '',
    postalCode: '',
    countryCode: '',
    timezone: browserTimezone(),
    startsAt: '',
    endsAt: '',
    lifespanDays: 30,
    audiences: ['all'],
  };
}

function formatDate(value: string | null) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.valueOf())
    ? value
    : new Intl.DateTimeFormat('en-US', {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(date);
}

function errorMessage(body: ApiResponse<unknown>, fallback: string) {
  return body.error?.message ?? fallback;
}

async function adminFetch<T>(
  token: string,
  url: string,
  init: RequestInit = {},
): Promise<ApiResponse<T>> {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  });
  const body =
    response.status === 204 ? {} : ((await response.json()) as ApiResponse<T>);
  if (!response.ok)
    throw new Error(errorMessage(body, 'The request could not be completed.'));
  return body;
}

function dateTimeParts(value: string) {
  const [date, time] = value.split('T');
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute] = time.split(':').map(Number);
  return { year, month, day, hour, minute };
}

function timezoneOffsetAt(timestamp: number, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date(timestamp));
  const values = Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, Number(part.value)]),
  );
  const localTimestamp = Date.UTC(
    values.year,
    values.month - 1,
    values.day,
    values.hour,
    values.minute,
    values.second,
  );
  return localTimestamp - timestamp;
}

function localDateTimeToIso(value: string, timezone: string) {
  if (!value) throw new Error('Enter both a start and end date and time.');
  const { year, month, day, hour, minute } = dateTimeParts(value);
  const wallClock = Date.UTC(year, month - 1, day, hour, minute);
  let instant = wallClock - timezoneOffsetAt(wallClock, timezone);
  instant = wallClock - timezoneOffsetAt(instant, timezone);

  const formatted = new Intl.DateTimeFormat('sv-SE', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date(instant));
  if (formatted.replace(' ', 'T') !== value)
    throw new Error(
      'Choose a valid local time for the selected timezone (it may fall in a daylight-saving transition).',
    );
  return new Date(instant).toISOString();
}

function label(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

export default function AdminEventsPanel({
  token,
  onClose,
}: {
  token: string;
  onClose: () => void;
}) {
  const [items, setItems] = useState<AdminEvent[]>([]);
  const [meta, setMeta] = useState<Meta>({});
  const [status, setStatus] = useState<EventStatus | 'all'>('pending');
  const [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);
  const [draft, setDraft] = useState<EventDraft>(blankDraft);
  const [formError, setFormError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [reviewingId, setReviewingId] = useState<string | null>(null);
  const [countries, setCountries] = useState<Country[]>([]);
  const [countriesLoading, setCountriesLoading] = useState(true);
  const [countriesError, setCountriesError] = useState<string | null>(null);

  const load = useCallback(
    async (nextOffset = offset, nextStatus = status) => {
      setLoading(true);
      setListError(null);
      try {
        const params = new URLSearchParams({
          status: nextStatus,
          limit: '20',
          offset: String(nextOffset),
        });
        const body = await adminFetch<AdminEvent[]>(
          token,
          `/api/v1/admin/events?${params}`,
        );
        setItems(body.data ?? []);
        setMeta(body.meta ?? {});
        setOffset(nextOffset);
      } catch (error) {
        setListError(
          error instanceof Error ? error.message : 'Unable to load events.',
        );
      } finally {
        setLoading(false);
      }
    },
    [offset, status, token],
  );

  useEffect(() => {
    void load(0);
  }, []); // Load the moderation queue once when the panel opens.

  useEffect(() => {
    let cancelled = false;

    async function loadCountries() {
      setCountriesLoading(true);
      setCountriesError(null);
      try {
        const allCountries: Country[] = [];
        let offset = 0;
        let hasMore = true;

        while (hasMore) {
          const params = new URLSearchParams({
            limit: '100',
            offset: String(offset),
          });
          const body = await adminFetch<Country[]>(
            token,
            `/api/v1/locations/countries?${params}`,
          );
          allCountries.push(...(body.data ?? []));
          hasMore = body.meta?.hasMore ?? false;
          offset = body.meta?.nextOffset ?? offset + 100;
        }

        if (!cancelled) setCountries(allCountries);
      } catch (error) {
        if (!cancelled) {
          setCountriesError(
            error instanceof Error
              ? error.message
              : 'Unable to load available countries.',
          );
        }
      } finally {
        if (!cancelled) setCountriesLoading(false);
      }
    }

    void loadCountries();
    return () => {
      cancelled = true;
    };
  }, [token]);

  const markdownPreview = useMemo(
    () =>
      draft.description || 'Start writing to preview the event description.',
    [draft.description],
  );

  function setField<Key extends keyof EventDraft>(
    key: Key,
    value: EventDraft[Key],
  ) {
    setDraft((current) => ({ ...current, [key]: value }));
  }

  function toggleAudience(audience: Audience) {
    setDraft((current) => {
      const selected = current.audiences.includes(audience)
        ? current.audiences.filter((value) => value !== audience)
        : [...current.audiences, audience];
      return { ...current, audiences: selected };
    });
  }

  async function createEvent() {
    setCreating(true);
    setFormError(null);
    try {
      if (!draft.title.trim() || !draft.description.trim())
        throw new Error('Enter an event title and description.');
      if (!draft.timezone.trim()) throw new Error('Enter an IANA timezone.');
      if (draft.audiences.length === 0)
        throw new Error('Select at least one target audience.');
      if (draft.eventType === 'online' && !draft.onlineUrl.trim())
        throw new Error('Enter the online event URL.');
      if (
        draft.eventType === 'physical' &&
        (!draft.locationName.trim() ||
          !draft.addressLine1.trim() ||
          !draft.city.trim() ||
          !draft.countryCode.trim())
      )
        throw new Error(
          'Select a country and enter the venue name, address, and city.',
        );
      if (draft.eventType === 'physical' && countriesError)
        throw new Error(
          'Available countries could not be loaded. Try again before creating the event.',
        );
      const common = {
        title: draft.title,
        description: draft.description,
        imageUrl: draft.imageUrl || null,
        eventUrl: draft.eventUrl || null,
        eventType: draft.eventType,
        timezone: draft.timezone,
        startsAt: localDateTimeToIso(draft.startsAt, draft.timezone),
        endsAt: localDateTimeToIso(draft.endsAt, draft.timezone),
        lifespanDays: draft.lifespanDays,
        audiences: draft.audiences,
      };
      const payload =
        draft.eventType === 'online'
          ? { ...common, onlineUrl: draft.onlineUrl }
          : {
              ...common,
              locationName: draft.locationName,
              addressLine1: draft.addressLine1,
              addressLine2: draft.addressLine2 || null,
              city: draft.city,
              regionName: draft.regionName || null,
              postalCode: draft.postalCode || null,
              countryCode: draft.countryCode,
            };
      await adminFetch(token, '/api/v1/admin/events', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      setDraft(blankDraft());
      setStatus('active');
      await load(0, 'active');
    } catch (error) {
      setFormError(
        error instanceof Error ? error.message : 'Unable to create the event.',
      );
    } finally {
      setCreating(false);
    }
  }

  async function review(event: AdminEvent, decision: EventStatus) {
    const action =
      decision === 'active'
        ? event.status === 'inactive'
          ? 'Reactivate'
          : 'Approve'
        : decision === 'inactive'
          ? 'Deactivate'
          : 'Reject';
    if (!window.confirm(`${action} “${event.title}”?`)) return;

    setReviewingId(event.id);
    setListError(null);
    try {
      await adminFetch(token, `/api/v1/admin/events/${event.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ decision }),
      });
      await load(offset);
    } catch (error) {
      setListError(
        error instanceof Error ? error.message : 'Unable to update the event.',
      );
    } finally {
      setReviewingId(null);
    }
  }

  return (
    <Box component="section" mt={3}>
      <Stack
        alignItems={{ xs: 'flex-start', sm: 'center' }}
        direction={{ xs: 'column', sm: 'row' }}
        justifyContent="space-between"
        mb={2}
        spacing={1}
      >
        <Typography component="h2" fontWeight={700} variant="h5">
          Events
        </Typography>
        <Button onClick={onClose}>Return to analytics</Button>
      </Stack>

      <Stack spacing={3}>
        <Card variant="outlined">
          <CardContent>
            <Stack spacing={2}>
              <Box>
                <Typography component="h3" fontWeight={700} variant="h6">
                  Create active event
                </Typography>
                <Typography color="text.secondary" variant="body2">
                  Administrator-created events are published immediately.
                </Typography>
              </Box>
              {formError && <Alert severity="error">{formError}</Alert>}
              <Box
                display="grid"
                gap={1.5}
                gridTemplateColumns={{ xs: '1fr', md: 'repeat(2, 1fr)' }}
              >
                <TextField
                  fullWidth
                  label="Title"
                  required
                  value={draft.title}
                  onChange={(event) => setField('title', event.target.value)}
                />
                <TextField
                  fullWidth
                  label="Picture URL"
                  type="url"
                  value={draft.imageUrl}
                  onChange={(event) => setField('imageUrl', event.target.value)}
                />
                <TextField
                  fullWidth
                  label="Registration or information URL"
                  type="url"
                  value={draft.eventUrl}
                  onChange={(event) => setField('eventUrl', event.target.value)}
                />
                <TextField
                  select
                  fullWidth
                  label="Event type"
                  value={draft.eventType}
                  onChange={(event) =>
                    setField(
                      'eventType',
                      event.target.value as EventDraft['eventType'],
                    )
                  }
                >
                  <MenuItem value="online">Online</MenuItem>
                  <MenuItem value="physical">Physical location</MenuItem>
                </TextField>
                <TextField
                  fullWidth
                  helperText="Use an IANA name, such as America/Chicago."
                  label="Timezone"
                  required
                  value={draft.timezone}
                  onChange={(event) => setField('timezone', event.target.value)}
                />
                <TextField
                  fullWidth
                  inputProps={{ min: 1, max: 365 }}
                  label="Visibility lifespan (days)"
                  required
                  type="number"
                  value={draft.lifespanDays}
                  onChange={(event) =>
                    setField('lifespanDays', Number(event.target.value))
                  }
                />
                <TextField
                  fullWidth
                  label="Starts"
                  required
                  slotProps={{ inputLabel: { shrink: true } }}
                  type="datetime-local"
                  value={draft.startsAt}
                  onChange={(event) => setField('startsAt', event.target.value)}
                />
                <TextField
                  fullWidth
                  label="Ends"
                  required
                  slotProps={{ inputLabel: { shrink: true } }}
                  type="datetime-local"
                  value={draft.endsAt}
                  onChange={(event) => setField('endsAt', event.target.value)}
                />
              </Box>

              {draft.eventType === 'online' ? (
                <TextField
                  fullWidth
                  label="Online event URL"
                  required
                  type="url"
                  value={draft.onlineUrl}
                  onChange={(event) =>
                    setField('onlineUrl', event.target.value)
                  }
                />
              ) : (
                <Box
                  display="grid"
                  gap={1.5}
                  gridTemplateColumns={{ xs: '1fr', md: 'repeat(2, 1fr)' }}
                >
                  <TextField
                    fullWidth
                    label="Venue name"
                    required
                    value={draft.locationName}
                    onChange={(event) =>
                      setField('locationName', event.target.value)
                    }
                  />
                  <TextField
                    fullWidth
                    label="Address line 1"
                    required
                    value={draft.addressLine1}
                    onChange={(event) =>
                      setField('addressLine1', event.target.value)
                    }
                  />
                  <TextField
                    fullWidth
                    label="Address line 2"
                    value={draft.addressLine2}
                    onChange={(event) =>
                      setField('addressLine2', event.target.value)
                    }
                  />
                  <TextField
                    fullWidth
                    label="City"
                    required
                    value={draft.city}
                    onChange={(event) => setField('city', event.target.value)}
                  />
                  <TextField
                    fullWidth
                    label="Region / state"
                    value={draft.regionName}
                    onChange={(event) =>
                      setField('regionName', event.target.value)
                    }
                  />
                  <TextField
                    fullWidth
                    label="Postal code"
                    value={draft.postalCode}
                    onChange={(event) =>
                      setField('postalCode', event.target.value)
                    }
                  />
                  <TextField
                    select
                    fullWidth
                    helperText={
                      countriesLoading
                        ? 'Loading available countries…'
                        : 'Countries available for event locations.'
                    }
                    label="Country"
                    required
                    value={draft.countryCode}
                    onChange={(event) =>
                      setField('countryCode', event.target.value)
                    }
                  >
                    <MenuItem disabled value="">
                      Select a country
                    </MenuItem>
                    {countries.map((country) => (
                      <MenuItem key={country.code} value={country.code}>
                        {country.name} ({country.code})
                      </MenuItem>
                    ))}
                  </TextField>
                </Box>
              )}

              {draft.eventType === 'physical' && countriesError && (
                <Alert severity="error">
                  Unable to load available countries: {countriesError}
                </Alert>
              )}

              <Box>
                <Typography fontWeight={600} variant="body2">
                  Target audiences
                </Typography>
                <Stack direction="row" flexWrap="wrap">
                  {audienceValues.map((audience) => (
                    <FormControlLabel
                      control={
                        <Checkbox
                          checked={draft.audiences.includes(audience)}
                          onChange={() => toggleAudience(audience)}
                        />
                      }
                      key={audience}
                      label={label(audience)}
                    />
                  ))}
                </Stack>
              </Box>

              <Box
                display="grid"
                gap={1.5}
                gridTemplateColumns={{ xs: '1fr', md: 'repeat(2, 1fr)' }}
              >
                <TextField
                  fullWidth
                  helperText="Markdown is rendered below without raw HTML."
                  label="Description (Markdown)"
                  minRows={8}
                  multiline
                  required
                  value={draft.description}
                  onChange={(event) =>
                    setField('description', event.target.value)
                  }
                />
                <Card variant="outlined">
                  <CardContent>
                    <Typography fontWeight={600} variant="body2">
                      Description preview
                    </Typography>
                    <Box sx={{ '& p:first-of-type': { mt: 1 } }}>
                      <ReactMarkdown>{markdownPreview}</ReactMarkdown>
                    </Box>
                  </CardContent>
                </Card>
              </Box>
              {draft.imageUrl && (
                <Box
                  alt="Event picture preview"
                  component="img"
                  src={draft.imageUrl}
                  sx={{ borderRadius: 1, maxHeight: 240, maxWidth: '100%' }}
                />
              )}
              <Box>
                <Button
                  disabled={creating}
                  variant="contained"
                  onClick={() => void createEvent()}
                >
                  {creating ? 'Creating…' : 'Create active event'}
                </Button>
              </Box>
            </Stack>
          </CardContent>
        </Card>

        <Divider />

        <Box>
          <Typography component="h3" fontWeight={700} gutterBottom variant="h6">
            Event moderation
          </Typography>
          <Stack spacing={2}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}>
              <TextField
                select
                label="Status"
                sx={{ minWidth: 180 }}
                value={status}
                onChange={(event) =>
                  setStatus(event.target.value as EventStatus | 'all')
                }
              >
                {statusValues.map((value) => (
                  <MenuItem key={value} value={value}>
                    {label(value)}
                  </MenuItem>
                ))}
              </TextField>
              <Button variant="contained" onClick={() => void load(0)}>
                Apply filters
              </Button>
            </Stack>
            {listError && <Alert severity="error">{listError}</Alert>}
            {loading ? (
              <Typography color="text.secondary">Loading events…</Typography>
            ) : items.length === 0 ? (
              <Alert severity="info">
                No events match the selected filters.
              </Alert>
            ) : (
              <Stack spacing={1.5}>
                {items.map((event) => (
                  <Card key={event.id} variant="outlined">
                    <CardContent>
                      <Stack spacing={1.25}>
                        <Stack
                          alignItems={{ xs: 'flex-start', sm: 'center' }}
                          direction={{ xs: 'column', sm: 'row' }}
                          justifyContent="space-between"
                          spacing={1}
                        >
                          <Box>
                            <Typography fontWeight={700}>
                              {event.title}
                            </Typography>
                            <Typography
                              color="text.secondary"
                              variant="caption"
                            >
                              {label(event.status)} · submitted{' '}
                              {formatDate(event.createdAt)}
                            </Typography>
                          </Box>
                          <Stack direction="row" flexWrap="wrap" gap={0.5}>
                            {event.audiences.map((audience) => (
                              <Chip
                                key={audience}
                                label={label(audience)}
                                size="small"
                              />
                            ))}
                          </Stack>
                        </Stack>
                        <Box sx={{ '& p:last-child': { mb: 0 } }}>
                          <ReactMarkdown>{event.description}</ReactMarkdown>
                        </Box>
                        <Typography color="text.secondary" variant="body2">
                          {formatDate(event.startsAt)} –{' '}
                          {formatDate(event.endsAt)} · {event.timezone}
                        </Typography>
                        <Typography color="text.secondary" variant="body2">
                          {event.eventType === 'online'
                            ? event.onlineUrl
                            : event.location
                              ? `${event.location.name}, ${event.location.addressLine1}, ${event.location.city}, ${event.location.countryCode}`
                              : 'Location unavailable'}
                        </Typography>
                        <Typography color="text.secondary" variant="body2">
                          {event.attendeeCount} RSVPs · {event.viewCount} unique
                          views
                          {event.expiresAt
                            ? ` · visible until ${formatDate(event.expiresAt)}`
                            : ''}
                        </Typography>
                        {event.eventUrl && (
                          <Typography
                            component="a"
                            href={event.eventUrl}
                            rel="noreferrer"
                            target="_blank"
                            variant="body2"
                          >
                            Open event link
                          </Typography>
                        )}
                        <Stack direction="row" flexWrap="wrap" gap={1}>
                          {event.status === 'pending' && (
                            <>
                              <Button
                                color="success"
                                disabled={reviewingId === event.id}
                                variant="contained"
                                onClick={() => void review(event, 'active')}
                              >
                                Approve
                              </Button>
                              <Button
                                color="error"
                                disabled={reviewingId === event.id}
                                variant="outlined"
                                onClick={() => void review(event, 'rejected')}
                              >
                                Reject
                              </Button>
                            </>
                          )}
                          {event.status === 'active' && (
                            <Button
                              disabled={reviewingId === event.id}
                              variant="outlined"
                              onClick={() => void review(event, 'inactive')}
                            >
                              Deactivate
                            </Button>
                          )}
                          {event.status === 'inactive' && (
                            <Button
                              color="success"
                              disabled={reviewingId === event.id}
                              variant="contained"
                              onClick={() => void review(event, 'active')}
                            >
                              Reactivate
                            </Button>
                          )}
                        </Stack>
                      </Stack>
                    </CardContent>
                  </Card>
                ))}
                <Stack direction="row" justifyContent="flex-end" spacing={1}>
                  <Button
                    disabled={offset === 0}
                    onClick={() => void load(Math.max(0, offset - 20))}
                  >
                    Previous
                  </Button>
                  <Button
                    disabled={!meta.hasMore}
                    onClick={() => void load(offset + 20)}
                  >
                    Next
                  </Button>
                </Stack>
              </Stack>
            )}
          </Stack>
        </Box>
      </Stack>
    </Box>
  );
}
