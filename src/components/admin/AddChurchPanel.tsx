'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { useEffect, useRef, useState } from 'react';

import { type ScheduleEntry, hasMassTime } from '@/lib/churches/schedule-entry';

import ServiceScheduleEditor from './ServiceScheduleEditor';
import { adminFetch } from './adminFetch';

type PostalLookup = {
  primaryCity: string | null;
  regionCodes: string[];
  latitude: number;
  longitude: number;
  timezone: string;
  dioceses: { id: string | null; name: string }[];
};

type SimilarChurch = {
  id: string;
  name: string;
  address: { line1: string; city: string; regionName: string | null };
};

type Form = {
  name: string;
  addressLine1: string;
  addressLine2: string;
  postalCode: string;
  city: string;
  regionName: string;
  countryCode: string;
  timezone: string;
  latitude: string;
  longitude: string;
  dioceseId: string;
};

type AutofillField =
  | 'city'
  | 'regionName'
  | 'timezone'
  | 'latitude'
  | 'longitude';

const emptyForm: Form = {
  name: '',
  addressLine1: '',
  addressLine2: '',
  postalCode: '',
  city: '',
  regionName: '',
  countryCode: 'US',
  timezone: '',
  latitude: '',
  longitude: '',
  dioceseId: '',
};

const isZip = (value: string) => /^\d{5}$/.test(value.trim());

function coordinate(value: string, limit: number) {
  const parsed = Number(value);
  return value.trim() !== '' &&
    Number.isFinite(parsed) &&
    Math.abs(parsed) <= limit
    ? parsed
    : null;
}

/** Lets an administrator add a church missing from the directory, together with its recurring schedule. */
export default function AddChurchPanel({ token }: { token: string }) {
  const [form, setForm] = useState<Form>(emptyForm);
  const [schedule, setSchedule] = useState<ScheduleEntry[]>([]);
  const [dioceses, setDioceses] = useState<PostalLookup['dioceses']>([]);
  const [similar, setSimilar] = useState<SimilarChurch[]>([]);
  const [zipNote, setZipNote] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [submitting, setSubmitting] = useState(false);
  // Fields the admin typed into themselves are never overwritten by ZIP autofill.
  const edited = useRef(new Set<AutofillField>());
  const zipRequest = useRef(0);

  function update(patch: Partial<Form>, field?: AutofillField) {
    if (field) edited.current.add(field);
    setForm((current) => ({ ...current, ...patch }));
    setSuccess('');
  }

  const zip = form.postalCode.trim();
  useEffect(() => {
    const requestId = ++zipRequest.current;
    if (!isZip(zip)) {
      setDioceses([]);
      setZipNote('');
      return;
    }
    void adminFetch<PostalLookup>(
      token,
      `/api/v1/locations/postal-codes/${zip}`,
    )
      .then((response) => {
        const lookup = response.data;
        if (requestId !== zipRequest.current || !lookup) return;
        const fill: Partial<Form> = {};
        if (!edited.current.has('city') && lookup.primaryCity)
          fill.city = lookup.primaryCity;
        if (!edited.current.has('regionName') && lookup.regionCodes[0])
          fill.regionName = lookup.regionCodes[0];
        if (!edited.current.has('timezone')) fill.timezone = lookup.timezone;
        if (!edited.current.has('latitude'))
          fill.latitude = String(lookup.latitude);
        if (!edited.current.has('longitude'))
          fill.longitude = String(lookup.longitude);
        setForm((current) => ({ ...current, ...fill }));
        setDioceses(lookup.dioceses.filter((item) => item.id));
        setZipNote(
          'City, state, time zone, and coordinates were filled from the ZIP. The coordinates are the ZIP’s center, so replace them if you know the exact location.',
        );
      })
      .catch(() => {
        if (requestId !== zipRequest.current) return;
        setDioceses([]);
        setZipNote('That ZIP was not found. Enter the details manually.');
      });
  }, [token, zip]);

  const name = form.name.trim();
  useEffect(() => {
    if (name.length < 2 || !isZip(zip)) {
      setSimilar([]);
      return;
    }
    let active = true;
    const timer = setTimeout(() => {
      void adminFetch<SimilarChurch[]>(
        token,
        `/api/v1/churches?${new URLSearchParams({
          q: name,
          postalCode: zip,
          limit: '5',
        })}`,
      )
        .then((response) => {
          if (active) setSimilar(response.data ?? []);
        })
        .catch(() => {
          if (active) setSimilar([]);
        });
    }, 400);
    return () => {
      active = false;
      clearTimeout(timer);
    };
  }, [token, name, zip]);

  async function submit() {
    setSuccess('');
    const latitude = coordinate(form.latitude, 90);
    const longitude = coordinate(form.longitude, 180);
    if (name.length < 2 || form.addressLine1.trim().length < 2) {
      setError('Enter the church name and street address.');
      return;
    }
    if (!form.city.trim() || !form.timezone.trim()) {
      setError('Enter the city and time zone.');
      return;
    }
    if (!/^[A-Za-z]{2}$/.test(form.countryCode.trim())) {
      setError('Enter a two-letter country code, such as US.');
      return;
    }
    if (latitude === null || longitude === null) {
      setError(
        'Enter valid latitude (-90 to 90) and longitude (-180 to 180) values.',
      );
      return;
    }
    if (!hasMassTime(schedule)) {
      setError('Add at least one Mass time.');
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      await adminFetch(token, '/api/v1/admin/churches', {
        method: 'POST',
        body: JSON.stringify({
          church: {
            name,
            addressLine1: form.addressLine1.trim(),
            addressLine2: form.addressLine2.trim() || null,
            city: form.city.trim(),
            regionName: form.regionName.trim() || null,
            postalCode: zip || null,
            countryCode: form.countryCode.trim().toUpperCase(),
            timezone: form.timezone.trim(),
            latitude,
            longitude,
            dioceseId: form.dioceseId || null,
          },
          serviceTimes: schedule.map(
            ({ serviceType, weekday, startTime, endTime }) => ({
              serviceType,
              weekday,
              startTime,
              endTime,
            }),
          ),
        }),
      });
      setSuccess(
        `Added ${name}. It is verified and now appears in church search.`,
      );
      setForm(emptyForm);
      setSchedule([]);
      setSimilar([]);
      setDioceses([]);
      setZipNote('');
      edited.current.clear();
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Unable to add the church.',
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Box component="section" mt={3}>
      <Typography component="h2" variant="h5" fontWeight={700} mb={2}>
        Add a Church
      </Typography>
      <Stack spacing={2}>
        <Alert severity="info">
          Use this for churches missing from the directory. A church needs at
          least one Mass time; confession and Eucharistic adoration are
          optional. It is marked verified as soon as you save.
        </Alert>
        {success && <Alert severity="success">{success}</Alert>}
        {error && <Alert severity="error">{error}</Alert>}

        <Typography variant="h6">Church details</Typography>
        <Box
          display="grid"
          gridTemplateColumns={{ xs: '1fr', md: 'repeat(2, 1fr)' }}
          gap={1.5}
        >
          <TextField
            label="Name"
            required
            value={form.name}
            onChange={(event) => update({ name: event.target.value })}
          />
          <TextField
            label="ZIP code"
            value={form.postalCode}
            onChange={(event) => update({ postalCode: event.target.value })}
            helperText="Fills in city, state, time zone, and coordinates."
            slotProps={{ htmlInput: { inputMode: 'numeric', maxLength: 10 } }}
          />
          <TextField
            label="Address"
            required
            value={form.addressLine1}
            onChange={(event) => update({ addressLine1: event.target.value })}
          />
          <TextField
            label="Address line 2"
            value={form.addressLine2}
            onChange={(event) => update({ addressLine2: event.target.value })}
          />
          <TextField
            label="City"
            required
            value={form.city}
            onChange={(event) => update({ city: event.target.value }, 'city')}
          />
          <TextField
            label="State/region"
            value={form.regionName}
            onChange={(event) =>
              update({ regionName: event.target.value }, 'regionName')
            }
            helperText="Use the two-letter state code, such as TX."
          />
          <TextField
            label="Country code"
            required
            value={form.countryCode}
            onChange={(event) =>
              update({ countryCode: event.target.value.toUpperCase() })
            }
          />
          <TextField
            label="Time zone"
            required
            value={form.timezone}
            onChange={(event) =>
              update({ timezone: event.target.value }, 'timezone')
            }
            helperText="IANA name, such as America/Chicago."
          />
          <TextField
            label="Latitude"
            required
            value={form.latitude}
            onChange={(event) =>
              update({ latitude: event.target.value }, 'latitude')
            }
          />
          <TextField
            label="Longitude"
            required
            value={form.longitude}
            onChange={(event) =>
              update({ longitude: event.target.value }, 'longitude')
            }
          />
          {dioceses.length > 0 && (
            <TextField
              select
              label="Diocese"
              value={form.dioceseId}
              onChange={(event) => update({ dioceseId: event.target.value })}
            >
              <MenuItem value="">Not set</MenuItem>
              {dioceses.map((diocese) => (
                <MenuItem key={diocese.id} value={diocese.id ?? ''}>
                  {diocese.name}
                </MenuItem>
              ))}
            </TextField>
          )}
        </Box>
        {zipNote && (
          <Typography variant="caption" color="text.secondary">
            {zipNote}
          </Typography>
        )}
        {similar.length > 0 && (
          <Alert severity="warning">
            Similar churches are already in the directory. Check that this isn’t
            a duplicate:
            <Box component="ul" sx={{ m: 0, pl: 3 }}>
              {similar.map((church) => (
                <li key={church.id}>
                  {church.name} — {church.address.line1}, {church.address.city}
                  {church.address.regionName
                    ? `, ${church.address.regionName}`
                    : ''}
                </li>
              ))}
            </Box>
          </Alert>
        )}

        <Typography variant="h6">Service times</Typography>
        <ServiceScheduleEditor value={schedule} onChange={setSchedule} />

        <Box>
          <Button
            variant="contained"
            disabled={submitting}
            onClick={() => void submit()}
          >
            Add church
          </Button>
        </Box>
      </Stack>
    </Box>
  );
}
