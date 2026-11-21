'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Chip from '@mui/material/Chip';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { useEffect, useState } from 'react';

import {
  churchImportExample,
  churchImportNotes,
} from '@/lib/churches/import-example';

import { adminFetch } from './adminFetch';

type ServiceTime = {
  serviceType: string;
  weekday: string;
  startTime: string;
  endTime?: string | null;
};

type ImportResult = {
  index: number;
  label: string;
  action: 'create' | 'update' | 'ambiguous' | 'invalid' | 'error';
  applied: boolean;
  message?: string;
  churchName?: string;
  churchId?: string;
  currentServiceTimes?: ServiceTime[];
  proposedServiceTimes?: ServiceTime[];
};

type DirectoryChurch = {
  id: string;
  name: string;
  address: {
    line1: string;
    city: string;
    regionName: string | null;
    postalCode: string | null;
  };
  scheduleStatus?: string | null;
};

type ImportResponse = {
  dryRun: boolean;
  results: ImportResult[];
  summary: { create: number; update: number; failed: number };
};

const MAX_FILE_BYTES = 1_000_000;
const exampleText = JSON.stringify(churchImportExample, null, 2);

/** Accepts { churches: [...] }, a bare array, or a single church entry. */
function extractChurches(text: string): unknown[] {
  const parsed: unknown = JSON.parse(text);
  if (Array.isArray(parsed)) return parsed;
  if (parsed && typeof parsed === 'object') {
    const churches = (parsed as { churches?: unknown }).churches;
    return Array.isArray(churches) ? churches : [parsed];
  }
  throw new Error('The file must contain a JSON object or array.');
}

function describeTimes(times?: ServiceTime[]) {
  if (!times || times.length === 0) return '—';
  return times
    .map(
      (time) =>
        `${time.serviceType} ${time.weekday.slice(0, 3)} ${time.startTime}${time.endTime ? `–${time.endTime}` : ''}`,
    )
    .join(', ');
}

function churchLabel(church: DirectoryChurch) {
  const { line1, city, regionName } = church.address;
  return `${church.name}, ${line1}, ${city}${regionName ? ` ${regionName}` : ''}`;
}

/** Appends an entry for the chosen church (churchId filled in) to whatever JSON is already in the box. */
function addChurchEntry(text: string, church: DirectoryChurch): string {
  const entry = {
    churchId: church.id,
    label: churchLabel(church),
    serviceTimes: [
      { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
    ],
  };
  let churches: unknown[] = [];
  try {
    if (text.trim()) churches = extractChurches(text);
  } catch {
    churches = [];
  }
  const alreadyListed = churches.some(
    (item) => (item as { churchId?: unknown } | null)?.churchId === church.id,
  );
  return JSON.stringify(
    { churches: alreadyListed ? churches : [...churches, entry] },
    null,
    2,
  );
}

/** Search the directory and add the chosen church, with its ID, to the import JSON. */
function ChurchPicker({
  token,
  onPick,
}: {
  token: string;
  onPick: (church: DirectoryChurch) => void;
}) {
  const [query, setQuery] = useState('');
  const [country, setCountry] = useState('US');
  const [results, setResults] = useState<DirectoryChurch[]>([]);
  const [status, setStatus] = useState<'idle' | 'loading' | 'error'>('idle');

  useEffect(() => {
    const term = query.trim();
    if (term.length < 2 || !/^[A-Za-z]{2}$/.test(country.trim())) {
      setResults([]);
      setStatus('idle');
      return;
    }
    let active = true;
    setStatus('loading');
    const timer = setTimeout(() => {
      adminFetch<DirectoryChurch[]>(
        token,
        `/api/v1/churches?${new URLSearchParams({
          q: term,
          countryCode: country.trim().toUpperCase(),
          limit: '8',
        })}`,
      )
        .then((response) => {
          if (!active) return;
          setResults(response.data ?? []);
          setStatus('idle');
        })
        .catch(() => {
          if (active) setStatus('error');
        });
    }, 350);
    return () => {
      active = false;
      clearTimeout(timer);
    };
  }, [token, query, country]);

  return (
    <Paper variant="outlined" sx={{ p: 2 }}>
      <Stack spacing={1.5}>
        <Typography variant="subtitle1" fontWeight={700}>
          Find a church
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Search the directory, then add the church to the JSON below. Its ID is
          filled in for you.
        </Typography>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
          <TextField
            inputProps={{ 'aria-label': 'Search churches by name' }}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Church name (min. 2 letters)"
            size="small"
            sx={{ flex: 1 }}
            value={query}
          />
          <TextField
            inputProps={{ 'aria-label': 'Country code', maxLength: 2 }}
            onChange={(event) => setCountry(event.target.value)}
            size="small"
            sx={{ width: 90 }}
            value={country}
          />
        </Stack>
        {status === 'loading' && (
          <Typography variant="caption">Searching…</Typography>
        )}
        {status === 'error' && (
          <Alert severity="warning">Churches could not be searched.</Alert>
        )}
        {status === 'idle' &&
          query.trim().length >= 2 &&
          results.length === 0 && (
            <Typography variant="body2" color="text.secondary">
              No churches found.
            </Typography>
          )}
        {results.map((church) => (
          <Stack
            key={church.id}
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1}
            alignItems={{ sm: 'center' }}
            justifyContent="space-between"
            sx={{ borderTop: 1, borderColor: 'divider', pt: 1 }}
          >
            <Box sx={{ minWidth: 0 }}>
              <Typography variant="body2" fontWeight={600}>
                {church.name}
              </Typography>
              <Typography
                variant="caption"
                color="text.secondary"
                display="block"
              >
                {church.address.line1}, {church.address.city}
                {church.address.regionName
                  ? ` ${church.address.regionName}`
                  : ''}
                {church.address.postalCode
                  ? ` ${church.address.postalCode}`
                  : ''}
              </Typography>
              <Typography
                variant="caption"
                sx={{ fontFamily: 'monospace', wordBreak: 'break-all' }}
              >
                ID: {church.id}
              </Typography>
            </Box>
            <Button
              aria-label={`Add ${church.name} to JSON`}
              onClick={() => onPick(church)}
              size="small"
              variant="outlined"
            >
              Add to JSON
            </Button>
          </Stack>
        ))}
      </Stack>
    </Paper>
  );
}

const actionColor: Record<
  ImportResult['action'],
  'success' | 'info' | 'warning' | 'error'
> = {
  create: 'success',
  update: 'info',
  ambiguous: 'warning',
  invalid: 'error',
  error: 'error',
};

/** Advanced: bulk-update church Mass, confession and adoration times from a JSON file, with a preview first. */
export default function ChurchScheduleImportPanel({
  token,
}: {
  token: string;
}) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [response, setResponse] = useState<ImportResponse | null>(null);

  async function loadFile(file: File | undefined) {
    if (!file) return;
    setResponse(null);
    if (file.size > MAX_FILE_BYTES) {
      setError('That file is larger than 1 MB.');
      return;
    }
    setError(null);
    setText(await file.text());
  }

  async function run(dryRun: boolean) {
    setError(null);
    let churches: unknown[];
    try {
      churches = extractChurches(text);
    } catch (parseError) {
      setError(
        parseError instanceof SyntaxError
          ? `This is not valid JSON: ${parseError.message}`
          : (parseError as Error).message,
      );
      return;
    }

    setBusy(true);
    try {
      const body = await adminFetch<ImportResponse>(
        token,
        '/api/v1/admin/churches/import',
        { method: 'POST', body: JSON.stringify({ dryRun, churches }) },
      );
      setResponse(body.data ?? null);
    } catch (failure) {
      setError(
        failure instanceof Error ? failure.message : 'The import failed.',
      );
    } finally {
      setBusy(false);
    }
  }

  function downloadExample() {
    const url = URL.createObjectURL(
      new Blob([exampleText], { type: 'application/json' }),
    );
    const link = document.createElement('a');
    link.href = url;
    link.download = 'church-schedule-import.example.json';
    link.click();
    URL.revokeObjectURL(url);
  }

  const applicable = response
    ? response.summary.create + response.summary.update
    : 0;

  return (
    <Stack spacing={2} sx={{ mt: 2 }}>
      <Alert severity="info">
        Advanced: upload or paste a JSON file of Mass, confession and adoration
        times. Churches are matched automatically and updated; missing churches
        are created. You will see a preview before anything is saved.
      </Alert>

      <ChurchPicker
        token={token}
        onPick={(church) => {
          setResponse(null);
          setText((current) => addChurchEntry(current, church));
        }}
      />

      <Paper variant="outlined" sx={{ p: 2 }}>
        <Stack spacing={1}>
          <Typography variant="subtitle1" fontWeight={700}>
            Expected format
          </Typography>
          <Box component="ul" sx={{ m: 0, pl: 3 }}>
            {churchImportNotes.map((note) => (
              <li key={note}>
                <Typography variant="body2">{note}</Typography>
              </li>
            ))}
          </Box>
          <Box
            component="pre"
            aria-label="Example import file"
            sx={{
              bgcolor: 'action.hover',
              borderRadius: 1,
              fontSize: 12,
              m: 0,
              maxHeight: 320,
              overflow: 'auto',
              p: 1.5,
            }}
          >
            {exampleText}
          </Box>
          <Stack direction="row" spacing={1}>
            <Button onClick={downloadExample} variant="outlined">
              Download example
            </Button>
            <Button onClick={() => setText(exampleText)} variant="text">
              Use example
            </Button>
          </Stack>
        </Stack>
      </Paper>

      <Stack spacing={1.5}>
        <Button
          component="label"
          variant="outlined"
          sx={{ alignSelf: 'start' }}
        >
          Choose JSON file
          <input
            accept="application/json,.json"
            hidden
            onChange={(event) => {
              void loadFile(event.target.files?.[0]);
              event.target.value = '';
            }}
            type="file"
          />
        </Button>
        <TextField
          inputProps={{ 'aria-label': 'Church schedule JSON' }}
          minRows={8}
          multiline
          onChange={(event) => {
            setText(event.target.value);
            setResponse(null);
          }}
          placeholder="…or paste JSON here"
          value={text}
        />
        <Stack direction="row" spacing={1}>
          <Button
            disabled={busy || text.trim() === ''}
            onClick={() => void run(true)}
            variant="contained"
          >
            Preview changes
          </Button>
          {response?.dryRun && applicable > 0 && (
            <Button
              color="success"
              disabled={busy}
              onClick={() => void run(false)}
              variant="contained"
            >
              Apply {applicable} change{applicable === 1 ? '' : 's'}
            </Button>
          )}
        </Stack>
      </Stack>

      {error && <Alert severity="error">{error}</Alert>}

      {response && (
        <Stack spacing={1}>
          <Alert severity={response.summary.failed > 0 ? 'warning' : 'success'}>
            {response.dryRun ? 'Preview: ' : 'Applied: '}
            {response.summary.create} to create, {response.summary.update} to
            update, {response.summary.failed} need attention.
            {!response.dryRun && ' Changes were saved.'}
          </Alert>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Church</TableCell>
                <TableCell>Church ID</TableCell>
                <TableCell>Result</TableCell>
                <TableCell>Current times</TableCell>
                <TableCell>New times</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {response.results.map((result) => (
                <TableRow key={result.index}>
                  <TableCell>
                    {result.churchName ?? result.label}
                    {result.message && (
                      <Typography
                        color="text.secondary"
                        display="block"
                        variant="caption"
                      >
                        {result.message}
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell
                    sx={{ fontFamily: 'monospace', wordBreak: 'break-all' }}
                  >
                    {result.churchId ?? '—'}
                  </TableCell>
                  <TableCell>
                    <Chip
                      color={actionColor[result.action]}
                      label={
                        result.applied ? `${result.action} ✓` : result.action
                      }
                      size="small"
                      variant="outlined"
                    />
                  </TableCell>
                  <TableCell>
                    {describeTimes(result.currentServiceTimes)}
                  </TableCell>
                  <TableCell>
                    {describeTimes(result.proposedServiceTimes)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Stack>
      )}
    </Stack>
  );
}
