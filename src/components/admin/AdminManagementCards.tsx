'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import CircularProgress from '@mui/material/CircularProgress';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogTitle from '@mui/material/DialogTitle';
import Divider from '@mui/material/Divider';
import FormControlLabel from '@mui/material/FormControlLabel';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import Switch from '@mui/material/Switch';
import Tab from '@mui/material/Tab';
import Tabs from '@mui/material/Tabs';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { useRouter, useSearchParams } from 'next/navigation';
import { type ReactNode, useCallback, useEffect, useState } from 'react';

import { contactSubjectValues } from '@/lib/schemas/contact';

import AdminAppMetrics from './AdminAppMetrics';
import AdminEventsPanel from './AdminEventsPanel';
import EmailCenter from './EmailCenter';

type Meta = { hasMore?: boolean; nextOffset?: number | null };
type ApiResponse<T> = { data?: T; meta?: Meta; error?: { message?: string } };
type ListState<T> = {
  items: T[];
  meta: Meta;
  loading: boolean;
  error: string | null;
};

type ContactRequest = {
  id: string;
  name: string;
  email: string;
  subject: string;
  other_subject: string | null;
  message: string;
  status: string;
  created_at: string;
};
type PrayerIntention = {
  id: string;
  creatorId: string;
  title: string;
  description: string;
  symbol: string | null;
  status: 'pending' | 'visible' | 'rejected';
  createdAt: string;
  reviewedAt: string | null;
  expiresAt: string | null;
};
type ExaminationQuestion = {
  id: string;
  category: 'single' | 'married' | 'religious';
  title: string;
  commandment: number;
  type: 'mortal' | 'grave';
  question: string;
  description: string;
  counsels: string[];
  prevention: string[];
  saints: string[];
  isActive: boolean;
};
type ChurchChangeRequest = {
  id: string;
  submitted_by: string;
  request_type: string;
  church_id: string | null;
  proposed_church: unknown;
  proposed_service_times: unknown;
  notes: string | null;
  status: 'pending' | 'approved' | 'rejected';
  rejection_reason: string | null;
  created_at: string;
};

const initialList = <T,>(): ListState<T> => ({
  items: [],
  meta: {},
  loading: false,
  error: null,
});

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

function Panel({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <Box component="section" mt={3}>
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        alignItems={{ xs: 'flex-start', sm: 'center' }}
        justifyContent="space-between"
        spacing={1}
        mb={2}
      >
        <Typography component="h2" variant="h5" fontWeight={700}>
          {title}
        </Typography>
        <Button onClick={onClose}>Return to analytics</Button>
      </Stack>
      {children}
    </Box>
  );
}

function ListFeedback<T>({
  state,
  children,
}: {
  state: ListState<T>;
  children: ReactNode;
}) {
  if (state.loading) {
    return (
      <Stack alignItems="center" py={5}>
        <CircularProgress aria-label="Loading" />
      </Stack>
    );
  }
  if (state.error) return <Alert severity="error">{state.error}</Alert>;
  if (state.items.length === 0)
    return (
      <Alert severity="info">No records match the selected filters.</Alert>
    );
  return <>{children}</>;
}

function Pagination({
  offset,
  hasMore,
  onPrevious,
  onNext,
}: {
  offset: number;
  hasMore: boolean;
  onPrevious: () => void;
  onNext: () => void;
}) {
  return (
    <Stack direction="row" spacing={1} justifyContent="flex-end">
      <Button disabled={offset === 0} onClick={onPrevious}>
        Previous
      </Button>
      <Button disabled={!hasMore} onClick={onNext}>
        Next
      </Button>
    </Stack>
  );
}

function ContactRequestsPanel({
  token,
  onClose,
}: {
  token: string;
  onClose: () => void;
}) {
  const [state, setState] = useState(initialList<ContactRequest>);
  const [filters, setFilters] = useState({
    status: 'all',
    created_at: '',
    email: '',
    name: '',
    subject: '',
  });
  const [offset, setOffset] = useState(0);
  const [selected, setSelected] = useState<ContactRequest | null>(null);
  const [replySubject, setReplySubject] = useState('');
  const [replyMessage, setReplyMessage] = useState('');
  const [sendingReply, setSendingReply] = useState(false);
  const [replyError, setReplyError] = useState<string | null>(null);
  const load = useCallback(
    async (nextOffset = offset) => {
      setState((current) => ({ ...current, loading: true, error: null }));
      try {
        const params = new URLSearchParams({
          status: filters.status,
          limit: '20',
          offset: String(nextOffset),
        });
        for (const [key, value] of Object.entries(filters))
          if (key !== 'status' && value) params.set(key, value);
        const body = await adminFetch<ContactRequest[]>(
          token,
          `/api/v1/admin/contact-requests?${params}`,
        );
        setState({
          items: body.data ?? [],
          meta: body.meta ?? {},
          loading: false,
          error: null,
        });
        setOffset(nextOffset);
      } catch (error) {
        setState((current) => ({
          ...current,
          loading: false,
          error:
            error instanceof Error
              ? error.message
              : 'Unable to load contact requests.',
        }));
      }
    },
    [filters, offset, token],
  );
  useEffect(() => {
    void load(0);
  }, []); // Load the default queue once when opened.

  async function sendReply() {
    if (!selected) return;
    setSendingReply(true);
    setReplyError(null);
    try {
      await adminFetch(
        token,
        `/api/v1/admin/contact-requests/${selected.id}/reply`,
        {
          method: 'POST',
          body: JSON.stringify({
            subject: replySubject,
            message: replyMessage,
          }),
        },
      );
      setSelected(null);
      setReplySubject('');
      setReplyMessage('');
      await load(offset);
    } catch (error) {
      setReplyError(
        error instanceof Error ? error.message : 'Unable to send the reply.',
      );
    } finally {
      setSendingReply(false);
    }
  }

  return (
    <Panel title="Contact Requests" onClose={onClose}>
      <Stack spacing={2}>
        <Alert severity="info">
          Send a branded response directly from a contact request. A successful
          send marks the request as done.
        </Alert>
        <Box
          display="grid"
          gridTemplateColumns={{ xs: '1fr', sm: 'repeat(2, 1fr)' }}
          gap={1.5}
        >
          <TextField
            select
            label="Status"
            value={filters.status}
            onChange={(event) =>
              setFilters({ ...filters, status: event.target.value })
            }
          >
            {['all', 'todo', 'inprogress', 'done'].map((value) => (
              <MenuItem key={value} value={value}>
                {value}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            label="Created date"
            type="date"
            slotProps={{ inputLabel: { shrink: true } }}
            value={filters.created_at}
            onChange={(event) =>
              setFilters({ ...filters, created_at: event.target.value })
            }
          />
          <TextField
            label="Email"
            type="email"
            value={filters.email}
            onChange={(event) =>
              setFilters({ ...filters, email: event.target.value })
            }
          />
          <TextField
            label="Name contains"
            value={filters.name}
            onChange={(event) =>
              setFilters({ ...filters, name: event.target.value })
            }
          />
          <TextField
            select
            label="Subject"
            value={filters.subject}
            onChange={(event) =>
              setFilters({ ...filters, subject: event.target.value })
            }
          >
            <MenuItem value="">Any subject</MenuItem>
            {contactSubjectValues.map((value) => (
              <MenuItem key={value} value={value}>
                {value}
              </MenuItem>
            ))}
          </TextField>
        </Box>
        <Button variant="contained" onClick={() => void load(0)}>
          Apply filters
        </Button>
        <ListFeedback state={state}>
          <Stack spacing={1}>
            {state.items.map((item) => (
              <Card key={item.id} variant="outlined">
                <CardContent>
                  <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    justifyContent="space-between"
                    spacing={1}
                  >
                    <Box>
                      <Typography fontWeight={700}>{item.name}</Typography>
                      <Typography variant="body2" color="text.secondary">
                        {item.email} · {item.subject}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {formatDate(item.created_at)} · {item.status}
                      </Typography>
                    </Box>
                    <Button
                      onClick={() => {
                        setSelected(item);
                        setReplySubject(`Re: ${item.subject}`);
                        setReplyMessage('');
                        setReplyError(null);
                      }}
                    >
                      View message
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
          <Pagination
            offset={offset}
            hasMore={Boolean(state.meta.hasMore)}
            onPrevious={() => void load(Math.max(0, offset - 20))}
            onNext={() => void load(offset + 20)}
          />
        </ListFeedback>
        {selected && (
          <Dialog
            open
            onClose={() => setSelected(null)}
            fullWidth
            maxWidth="sm"
          >
            <DialogTitle>
              {selected.subject}
              {selected.other_subject ? `: ${selected.other_subject}` : ''}
            </DialogTitle>
            <DialogContent dividers>
              <Stack spacing={1.5}>
                <Typography variant="body2">
                  From: {selected.name} &lt;{selected.email}&gt;
                </Typography>
                <Typography whiteSpace="pre-wrap">
                  {selected.message}
                </Typography>
                <Divider />
                <Typography fontWeight={700}>Reply by email</Typography>
                {replyError && <Alert severity="error">{replyError}</Alert>}
                <TextField
                  label="Subject"
                  value={replySubject}
                  onChange={(event) => setReplySubject(event.target.value)}
                  inputProps={{ maxLength: 160 }}
                />
                <TextField
                  label="Message"
                  value={replyMessage}
                  onChange={(event) => setReplyMessage(event.target.value)}
                  multiline
                  minRows={4}
                  inputProps={{ maxLength: 10_000 }}
                />
              </Stack>
            </DialogContent>
            <DialogActions>
              <Button
                disabled={sendingReply || !replySubject || !replyMessage}
                variant="contained"
                onClick={() => void sendReply()}
              >
                {sendingReply ? 'Sending…' : 'Send reply'}
              </Button>
              <Button onClick={() => setSelected(null)}>Close</Button>
            </DialogActions>
          </Dialog>
        )}
      </Stack>
    </Panel>
  );
}

function PrayerIntentionsPanel({
  token,
  onClose,
}: {
  token: string;
  onClose: () => void;
}) {
  const [state, setState] = useState(initialList<PrayerIntention>);
  const [status, setStatus] = useState('pending');
  const [createdAt, setCreatedAt] = useState('');
  const [offset, setOffset] = useState(0);
  const [submitting, setSubmitting] = useState<string | null>(null);
  const load = useCallback(
    async (nextOffset = offset) => {
      setState((current) => ({ ...current, loading: true, error: null }));
      try {
        const params = new URLSearchParams({
          status,
          limit: '20',
          offset: String(nextOffset),
        });
        if (createdAt) params.set('createdAt', createdAt);
        const body = await adminFetch<PrayerIntention[]>(
          token,
          `/api/v1/admin/prayer-intentions?${params}`,
        );
        setState({
          items: body.data ?? [],
          meta: body.meta ?? {},
          loading: false,
          error: null,
        });
        setOffset(nextOffset);
      } catch (error) {
        setState((current) => ({
          ...current,
          loading: false,
          error:
            error instanceof Error
              ? error.message
              : 'Unable to load prayer intentions.',
        }));
      }
    },
    [createdAt, offset, status, token],
  );
  useEffect(() => {
    void load(0);
  }, []);
  async function review(
    item: PrayerIntention,
    decision: 'visible' | 'rejected',
  ) {
    if (
      !window.confirm(
        `${decision === 'visible' ? 'Approve' : 'Reject'} “${item.title}”?`,
      )
    )
      return;
    setSubmitting(item.id);
    try {
      await adminFetch(token, `/api/v1/admin/prayer-intentions/${item.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ decision }),
      });
      await load(offset);
    } catch (error) {
      setState((current) => ({
        ...current,
        error:
          error instanceof Error
            ? error.message
            : 'Unable to review the prayer intention.',
      }));
    } finally {
      setSubmitting(null);
    }
  }
  return (
    <Panel title="Prayer Intention Review" onClose={onClose}>
      <Stack spacing={2}>
        <Box
          display="grid"
          gridTemplateColumns={{ xs: '1fr', sm: 'repeat(2, 1fr)' }}
          gap={1.5}
        >
          <TextField
            select
            label="Status"
            value={status}
            onChange={(event) => setStatus(event.target.value)}
          >
            {['pending', 'visible', 'rejected', 'all'].map((value) => (
              <MenuItem key={value} value={value}>
                {value}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            label="Created date"
            type="date"
            slotProps={{ inputLabel: { shrink: true } }}
            value={createdAt}
            onChange={(event) => setCreatedAt(event.target.value)}
          />
        </Box>
        <Button variant="contained" onClick={() => void load(0)}>
          Apply filters
        </Button>
        <ListFeedback state={state}>
          <Stack spacing={1}>
            {state.items.map((item) => (
              <Card key={item.id} variant="outlined">
                <CardContent>
                  <Stack spacing={1}>
                    <Box>
                      <Typography fontWeight={700}>{item.title}</Typography>
                      <Typography variant="body2" color="text.secondary">
                        {item.description}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {item.status} · submitted {formatDate(item.createdAt)}
                      </Typography>
                    </Box>
                    {item.status === 'pending' && (
                      <Stack direction="row" spacing={1}>
                        <Button
                          disabled={submitting === item.id}
                          color="success"
                          variant="contained"
                          onClick={() => void review(item, 'visible')}
                        >
                          Approve
                        </Button>
                        <Button
                          disabled={submitting === item.id}
                          color="error"
                          variant="outlined"
                          onClick={() => void review(item, 'rejected')}
                        >
                          Reject
                        </Button>
                      </Stack>
                    )}
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
          <Pagination
            offset={offset}
            hasMore={Boolean(state.meta.hasMore)}
            onPrevious={() => void load(Math.max(0, offset - 20))}
            onNext={() => void load(offset + 20)}
          />
        </ListFeedback>
      </Stack>
    </Panel>
  );
}

type QuestionDraft = Omit<ExaminationQuestion, 'id'>;
const blankQuestion: QuestionDraft = {
  category: 'single',
  title: '',
  commandment: 1,
  type: 'mortal',
  question: '',
  description: '',
  counsels: [''],
  prevention: [''],
  saints: [''],
  isActive: true,
};
function splitList(value: string) {
  return value
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean);
}

function ExaminationPanel({
  token,
  onClose,
}: {
  token: string;
  onClose: () => void;
}) {
  const [state, setState] = useState(initialList<ExaminationQuestion>);
  const [includeInactive, setIncludeInactive] = useState(false);
  const [filters, setFilters] = useState({
    category: '',
    saint: '',
    commandment: '',
    type: '',
  });
  const [offset, setOffset] = useState(0);
  const [draft, setDraft] = useState<QuestionDraft>(blankQuestion);
  const [editing, setEditing] = useState<ExaminationQuestion | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const load = useCallback(
    async (nextOffset = offset) => {
      setState((current) => ({ ...current, loading: true, error: null }));
      try {
        const params = new URLSearchParams({
          includeInactive: String(includeInactive),
          limit: '20',
          offset: String(nextOffset),
        });
        for (const [key, value] of Object.entries(filters)) {
          if (value) params.set(key, value);
        }
        const body = await adminFetch<ExaminationQuestion[]>(
          token,
          `/api/v1/admin/examination-of-conscience?${params}`,
        );
        setState({
          items: body.data ?? [],
          meta: body.meta ?? {},
          loading: false,
          error: null,
        });
        setOffset(nextOffset);
      } catch (error) {
        setState((current) => ({
          ...current,
          loading: false,
          error:
            error instanceof Error
              ? error.message
              : 'Unable to load questions.',
        }));
      }
    },
    [filters, includeInactive, offset, token],
  );
  useEffect(() => {
    void load(0);
  }, []);
  function beginEdit(question: ExaminationQuestion) {
    setEditing(question);
    setDraft({ ...question });
    setFormOpen(true);
    setFormError(null);
  }
  async function save() {
    setFormError(null);
    const payload = {
      ...draft,
      counsels: draft.counsels.filter(Boolean),
      prevention: draft.prevention.filter(Boolean),
      saints: draft.saints.filter(Boolean),
    };
    if (
      !payload.title ||
      !payload.question ||
      !payload.description ||
      !payload.counsels.length ||
      !payload.prevention.length ||
      !payload.saints.length
    ) {
      setFormError(
        'Complete all text fields and provide at least one counsel, prevention item, and saint.',
      );
      return;
    }
    try {
      await adminFetch(
        token,
        editing
          ? `/api/v1/admin/examination-of-conscience/${editing.id}`
          : '/api/v1/admin/examination-of-conscience',
        { method: editing ? 'PATCH' : 'POST', body: JSON.stringify(payload) },
      );
      setEditing(null);
      setDraft(blankQuestion);
      setFormOpen(false);
      await load(0);
    } catch (error) {
      setFormError(
        error instanceof Error ? error.message : 'Unable to save the question.',
      );
    }
  }
  async function remove(question: ExaminationQuestion) {
    if (!window.confirm(`Delete “${question.title}”? This cannot be undone.`))
      return;
    try {
      await adminFetch(
        token,
        `/api/v1/admin/examination-of-conscience/${question.id}`,
        { method: 'DELETE' },
      );
      await load(offset);
    } catch (error) {
      setState((current) => ({
        ...current,
        error:
          error instanceof Error
            ? error.message
            : 'Unable to delete the question.',
      }));
    }
  }
  return (
    <Panel title="Examination of Conscience" onClose={onClose}>
      <Stack spacing={2}>
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          spacing={1}
          justifyContent="space-between"
        >
          <FormControlLabel
            control={
              <Switch
                checked={includeInactive}
                onChange={(event) => setIncludeInactive(event.target.checked)}
              />
            }
            label="Include inactive"
          />
          <Stack direction="row" spacing={1}>
            <Button onClick={() => void load(0)}>Refresh</Button>
            <Button
              variant="contained"
              onClick={() => {
                setEditing(null);
                setDraft(blankQuestion);
                setFormOpen(true);
                setFormError(null);
              }}
            >
              Create question
            </Button>
          </Stack>
        </Stack>
        <Box
          display="grid"
          gridTemplateColumns={{ xs: '1fr', sm: 'repeat(2, 1fr)' }}
          gap={1.5}
        >
          <TextField
            select
            label="Category"
            value={filters.category}
            onChange={(event) =>
              setFilters({ ...filters, category: event.target.value })
            }
          >
            <MenuItem value="">Any category</MenuItem>
            {['single', 'married', 'religious'].map((value) => (
              <MenuItem key={value} value={value}>
                {value}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            label="Severity"
            value={filters.type}
            onChange={(event) =>
              setFilters({ ...filters, type: event.target.value })
            }
          >
            <MenuItem value="">Any severity</MenuItem>
            {['mortal', 'grave'].map((value) => (
              <MenuItem key={value} value={value}>
                {value}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            label="Saint"
            value={filters.saint}
            onChange={(event) =>
              setFilters({ ...filters, saint: event.target.value })
            }
          />
          <TextField
            label="Commandment"
            type="number"
            inputProps={{ min: 1, max: 10 }}
            value={filters.commandment}
            onChange={(event) =>
              setFilters({ ...filters, commandment: event.target.value })
            }
          />
        </Box>
        <Button variant="outlined" onClick={() => void load(0)}>
          Apply filters
        </Button>
        {formOpen && (
          <Card variant="outlined">
            <CardContent>
              <Stack spacing={1.5}>
                <Typography fontWeight={700}>
                  {editing ? 'Edit question' : 'Create question'}
                </Typography>
                {formError && <Alert severity="error">{formError}</Alert>}
                <Box
                  display="grid"
                  gridTemplateColumns={{ xs: '1fr', sm: 'repeat(2, 1fr)' }}
                  gap={1.5}
                >
                  <TextField
                    select
                    label="Category"
                    value={draft.category}
                    onChange={(event) =>
                      setDraft({
                        ...draft,
                        category: event.target
                          .value as QuestionDraft['category'],
                      })
                    }
                  >
                    {['single', 'married', 'religious'].map((value) => (
                      <MenuItem key={value} value={value}>
                        {value}
                      </MenuItem>
                    ))}
                  </TextField>
                  <TextField
                    select
                    label="Severity"
                    value={draft.type}
                    onChange={(event) =>
                      setDraft({
                        ...draft,
                        type: event.target.value as QuestionDraft['type'],
                      })
                    }
                  >
                    {['mortal', 'grave'].map((value) => (
                      <MenuItem key={value} value={value}>
                        {value}
                      </MenuItem>
                    ))}
                  </TextField>
                  <TextField
                    label="Title"
                    value={draft.title}
                    onChange={(event) =>
                      setDraft({ ...draft, title: event.target.value })
                    }
                  />
                  <TextField
                    label="Commandment"
                    type="number"
                    inputProps={{ min: 1, max: 10 }}
                    value={draft.commandment}
                    onChange={(event) =>
                      setDraft({
                        ...draft,
                        commandment: Number(event.target.value),
                      })
                    }
                  />
                </Box>
                <TextField
                  multiline
                  minRows={2}
                  label="Question"
                  value={draft.question}
                  onChange={(event) =>
                    setDraft({ ...draft, question: event.target.value })
                  }
                />
                <TextField
                  multiline
                  minRows={3}
                  label="Description"
                  value={draft.description}
                  onChange={(event) =>
                    setDraft({ ...draft, description: event.target.value })
                  }
                />
                <TextField
                  multiline
                  minRows={2}
                  label="Counsels (one per line)"
                  value={draft.counsels.join('\n')}
                  onChange={(event) =>
                    setDraft({
                      ...draft,
                      counsels: splitList(event.target.value),
                    })
                  }
                />
                <TextField
                  multiline
                  minRows={2}
                  label="Prevention (one per line)"
                  value={draft.prevention.join('\n')}
                  onChange={(event) =>
                    setDraft({
                      ...draft,
                      prevention: splitList(event.target.value),
                    })
                  }
                />
                <TextField
                  multiline
                  minRows={2}
                  label="Saints (one per line)"
                  value={draft.saints.join('\n')}
                  onChange={(event) =>
                    setDraft({
                      ...draft,
                      saints: splitList(event.target.value),
                    })
                  }
                />
                <FormControlLabel
                  control={
                    <Switch
                      checked={draft.isActive}
                      onChange={(event) =>
                        setDraft({ ...draft, isActive: event.target.checked })
                      }
                    />
                  }
                  label="Active"
                />
                <Stack direction="row" spacing={1}>
                  <Button variant="contained" onClick={() => void save()}>
                    Save
                  </Button>
                  <Button
                    onClick={() => {
                      setEditing(null);
                      setDraft(blankQuestion);
                      setFormOpen(false);
                      setFormError(null);
                    }}
                  >
                    Cancel
                  </Button>
                </Stack>
              </Stack>
            </CardContent>
          </Card>
        )}
        <ListFeedback state={state}>
          <Stack spacing={1}>
            {state.items.map((item) => (
              <Card key={item.id} variant="outlined">
                <CardContent>
                  <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    spacing={1}
                    justifyContent="space-between"
                  >
                    <Box>
                      <Typography fontWeight={700}>{item.title}</Typography>
                      <Typography variant="body2">{item.question}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        {item.category} · commandment {item.commandment} ·{' '}
                        {item.type} · {item.isActive ? 'active' : 'inactive'}
                      </Typography>
                    </Box>
                    <Stack direction="row" spacing={1}>
                      <Button onClick={() => beginEdit(item)}>Edit</Button>
                      <Button color="error" onClick={() => void remove(item)}>
                        Delete
                      </Button>
                    </Stack>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
          <Pagination
            offset={offset}
            hasMore={Boolean(state.meta.hasMore)}
            onPrevious={() => void load(Math.max(0, offset - 20))}
            onNext={() => void load(offset + 20)}
          />
        </ListFeedback>
      </Stack>
    </Panel>
  );
}

function ChurchRequestsPanel({
  token,
  onClose,
}: {
  token: string;
  onClose: () => void;
}) {
  const [state, setState] = useState(initialList<ChurchChangeRequest>);
  const [status, setStatus] = useState('all');
  const [offset, setOffset] = useState(0);
  const [selected, setSelected] = useState<ChurchChangeRequest | null>(null);
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const load = useCallback(
    async (nextOffset = offset) => {
      setState((current) => ({ ...current, loading: true, error: null }));
      try {
        const body = await adminFetch<ChurchChangeRequest[]>(
          token,
          `/api/v1/admin/church-change-requests?status=${status}&limit=20&offset=${nextOffset}`,
        );
        setState({
          items: body.data ?? [],
          meta: body.meta ?? {},
          loading: false,
          error: null,
        });
        setOffset(nextOffset);
      } catch (error) {
        setState((current) => ({
          ...current,
          loading: false,
          error:
            error instanceof Error
              ? error.message
              : 'Unable to load church change requests.',
        }));
      }
    },
    [offset, status, token],
  );
  useEffect(() => {
    void load(0);
  }, []);
  async function review(decision: 'approved' | 'rejected') {
    if (
      !selected ||
      !window.confirm(
        `${decision === 'approved' ? 'Approve' : 'Reject'} this church change request?`,
      )
    )
      return;
    setSubmitting(true);
    try {
      await adminFetch(
        token,
        `/api/v1/admin/church-change-requests/${selected.id}`,
        {
          method: 'PATCH',
          body: JSON.stringify({
            decision,
            rejectionReason: decision === 'rejected' ? reason || null : null,
          }),
        },
      );
      setSelected(null);
      setReason('');
      await load(offset);
    } catch (error) {
      setState((current) => ({
        ...current,
        error:
          error instanceof Error
            ? error.message
            : 'Unable to review the church change request.',
      }));
    } finally {
      setSubmitting(false);
    }
  }
  return (
    <Panel title="Church Change Requests" onClose={onClose}>
      <Stack spacing={2}>
        <Stack direction="row" spacing={1}>
          <TextField
            select
            label="Status"
            value={status}
            onChange={(event) => setStatus(event.target.value)}
            sx={{ minWidth: 180 }}
          >
            {['all', 'pending', 'approved', 'rejected'].map((value) => (
              <MenuItem key={value} value={value}>
                {value}
              </MenuItem>
            ))}
          </TextField>
          <Button variant="contained" onClick={() => void load(0)}>
            Apply
          </Button>
        </Stack>
        <ListFeedback state={state}>
          <Stack spacing={1}>
            {state.items.map((item) => (
              <Card key={item.id} variant="outlined">
                <CardContent>
                  <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    spacing={1}
                    justifyContent="space-between"
                  >
                    <Box>
                      <Typography fontWeight={700}>
                        {item.request_type.replace('_', ' ')}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {item.status} · submitted {formatDate(item.created_at)}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        Church ID: {item.church_id ?? 'New church'}
                      </Typography>
                    </Box>
                    <Button
                      onClick={() => {
                        setSelected(item);
                        setReason('');
                      }}
                    >
                      Review details
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
          <Pagination
            offset={offset}
            hasMore={Boolean(state.meta.hasMore)}
            onPrevious={() => void load(Math.max(0, offset - 20))}
            onNext={() => void load(offset + 20)}
          />
        </ListFeedback>
        {selected && (
          <Dialog
            open
            onClose={() => setSelected(null)}
            fullWidth
            maxWidth="sm"
          >
            <DialogTitle>Church change request</DialogTitle>
            <DialogContent dividers>
              <Stack spacing={2}>
                <Typography variant="body2">
                  Submitted by: {selected.submitted_by}
                </Typography>
                <Box>
                  <Typography fontWeight={700}>Proposed church</Typography>
                  <Box
                    component="pre"
                    sx={{
                      whiteSpace: 'pre-wrap',
                      overflowWrap: 'anywhere',
                      m: 0,
                    }}
                  >
                    {JSON.stringify(selected.proposed_church, null, 2)}
                  </Box>
                </Box>
                <Box>
                  <Typography fontWeight={700}>
                    Proposed service times
                  </Typography>
                  <Box
                    component="pre"
                    sx={{
                      whiteSpace: 'pre-wrap',
                      overflowWrap: 'anywhere',
                      m: 0,
                    }}
                  >
                    {JSON.stringify(selected.proposed_service_times, null, 2)}
                  </Box>
                </Box>
                {selected.notes && (
                  <Typography whiteSpace="pre-wrap">
                    Notes: {selected.notes}
                  </Typography>
                )}
                {selected.status === 'pending' && (
                  <TextField
                    label="Rejection reason (optional)"
                    multiline
                    minRows={3}
                    value={reason}
                    onChange={(event) => setReason(event.target.value)}
                    inputProps={{ maxLength: 2000 }}
                  />
                )}
              </Stack>
            </DialogContent>
            <DialogActions>
              {selected.status === 'pending' && (
                <>
                  <Button
                    disabled={submitting}
                    color="error"
                    onClick={() => void review('rejected')}
                  >
                    Reject
                  </Button>
                  <Button
                    disabled={submitting}
                    variant="contained"
                    color="success"
                    onClick={() => void review('approved')}
                  >
                    Approve
                  </Button>
                </>
              )}
              <Button onClick={() => setSelected(null)}>Close</Button>
            </DialogActions>
          </Dialog>
        )}
      </Stack>
    </Panel>
  );
}

function UserDeletionPanel({
  token,
  onClose,
}: {
  token: string;
  onClose: () => void;
}) {
  type SearchResult = {
    id: string;
    email: string | null;
    status: string;
    createdAt: string;
    displayName: string | null;
    username: string | null;
    isProtectedAdmin: boolean;
  };
  type PreviewRecord = {
    recordType: string;
    occurredAt: string;
    record: unknown;
  };
  type Preview = {
    account: {
      id: string;
      email: string | null;
      status: string;
      email_verified_at: string | null;
      last_login_at: string | null;
      created_at: string;
      updated_at: string;
    };
    profile: Record<string, unknown> | null;
    notificationPreferences: Record<string, unknown> | null;
    isProtectedAdmin: boolean;
    anonymousRosaryContribution: number;
    sections: Record<'account' | 'community' | 'progress' | 'prayer', number>;
    records: PreviewRecord[];
    recordCount: number;
  };
  const sections = [
    { value: 'account', label: 'Account' },
    { value: 'community', label: 'Community' },
    { value: 'progress', label: 'Progress' },
    { value: 'prayer', label: 'Prayer' },
  ] as const;
  type Section = (typeof sections)[number]['value'];
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState('');
  const [selected, setSelected] = useState<SearchResult | null>(null);
  const [section, setSection] = useState<Section>('account');
  const [offset, setOffset] = useState(0);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [previewMeta, setPreviewMeta] = useState<Meta>({});
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [previewError, setPreviewError] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [state, setState] = useState<
    'idle' | 'submitting' | 'success' | 'error'
  >('idle');
  const [error, setError] = useState('');

  async function search() {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      setSearchError(
        'Enter at least two characters of an email address or an exact UUID.',
      );
      return;
    }
    setSearching(true);
    setSearchError('');
    try {
      const response = await adminFetch<SearchResult[]>(
        token,
        `/api/v1/admin/users?q=${encodeURIComponent(trimmed)}`,
      );
      setResults(response.data ?? []);
    } catch (cause) {
      setSearchError(
        cause instanceof Error
          ? cause.message
          : 'Unable to search user accounts.',
      );
    } finally {
      setSearching(false);
    }
  }

  const loadPreview = useCallback(
    async (target: SearchResult, nextSection: Section, nextOffset: number) => {
      setLoadingPreview(true);
      setPreviewError('');
      try {
        const response = await adminFetch<Preview>(
          token,
          `/api/v1/admin/users/${target.id}/deletion-preview?section=${nextSection}&limit=25&offset=${nextOffset}`,
        );
        setPreview(response.data ?? null);
        setPreviewMeta(response.meta ?? {});
      } catch (cause) {
        setPreviewError(
          cause instanceof Error
            ? cause.message
            : 'Unable to load the account deletion preview.',
        );
      } finally {
        setLoadingPreview(false);
      }
    },
    [token],
  );

  useEffect(() => {
    if (selected) void loadPreview(selected, section, offset);
  }, [loadPreview, offset, section, selected]);

  function selectUser(user: SearchResult) {
    setSelected(user);
    setSection('account');
    setOffset(0);
    setPreview(null);
    setPreviewError('');
    setConfirmation('');
    setState('idle');
    setError('');
  }

  function closePreview() {
    setSelected(null);
    setPreview(null);
    setConfirmation('');
    setPreviewError('');
    setState('idle');
    setError('');
  }

  async function remove() {
    if (!selected) return;
    setState('submitting');
    try {
      await adminFetch(token, `/api/v1/admin/users/${selected.id}`, {
        method: 'DELETE',
      });
      setState('success');
      setSelected(null);
      setPreview(null);
      setConfirmation('');
      setResults((current) =>
        current.filter((user) => user.id !== selected.id),
      );
    } catch (cause) {
      setState('error');
      setError(
        cause instanceof Error
          ? cause.message
          : 'Unable to delete the account.',
      );
    }
  }
  return (
    <Panel title="Permanently Delete User Account" onClose={onClose}>
      <Stack spacing={2}>
        <Alert severity="error">
          This permanently deletes the user’s Auth identity and linked
          application data. This action cannot be undone.
        </Alert>
        {state === 'success' && (
          <Alert severity="success">
            The user account was permanently deleted.
          </Alert>
        )}
        {state === 'error' && <Alert severity="error">{error}</Alert>}
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
          <TextField
            fullWidth
            label="Search by email or UUID"
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setSearchError('');
            }}
            onKeyDown={(event) => {
              if (event.key === 'Enter') void search();
            }}
            helperText="Email matches may contain the entered text. UUIDs must match exactly."
          />
          <Button
            variant="contained"
            disabled={searching}
            onClick={() => void search()}
          >
            {searching ? 'Searching…' : 'Search'}
          </Button>
        </Stack>
        {searchError && <Alert severity="error">{searchError}</Alert>}
        {results.length > 0 && (
          <Stack spacing={1}>
            {results.map((user) => (
              <Card key={user.id} variant="outlined">
                <CardContent>
                  <Stack
                    direction={{ xs: 'column', md: 'row' }}
                    justifyContent="space-between"
                    alignItems={{ xs: 'flex-start', md: 'center' }}
                    spacing={1}
                  >
                    <Box>
                      <Typography fontWeight={700}>
                        {user.displayName ||
                          user.username ||
                          user.email ||
                          'Unnamed account'}
                      </Typography>
                      <Typography variant="body2">
                        {user.email || 'No email address'}
                      </Typography>
                      <Typography variant="caption" component="div">
                        {user.id} · Created {formatDate(user.createdAt)} ·{' '}
                        {user.status}
                        {user.isProtectedAdmin
                          ? ' · Administrator account'
                          : ''}
                      </Typography>
                    </Box>
                    <Button onClick={() => selectUser(user)}>
                      Review account
                    </Button>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
        )}
        {selected && (
          <Dialog
            open
            maxWidth="lg"
            fullWidth
            onClose={state === 'submitting' ? undefined : closePreview}
          >
            <DialogTitle>Review account before permanent deletion</DialogTitle>
            <DialogContent dividers>
              {loadingPreview && !preview ? (
                <Stack alignItems="center" py={5}>
                  <CircularProgress aria-label="Loading account review" />
                </Stack>
              ) : previewError ? (
                <Alert severity="error">{previewError}</Alert>
              ) : preview ? (
                <Stack spacing={2}>
                  {preview.isProtectedAdmin && (
                    <Alert severity="warning">
                      This is an administrator account. It can be reviewed, but
                      it cannot be deleted from this tool.
                    </Alert>
                  )}
                  <Box>
                    <Typography variant="h6">
                      {(preview.profile?.display_name as string) ||
                        (preview.profile?.username as string) ||
                        preview.account.email ||
                        'Unnamed account'}
                    </Typography>
                    <Typography variant="body2">
                      {preview.account.email || 'No email address'} ·{' '}
                      {preview.account.id}
                    </Typography>
                    <Typography variant="body2">
                      Created {formatDate(preview.account.created_at)} · Last
                      login {formatDate(preview.account.last_login_at)} · Email
                      verified {formatDate(preview.account.email_verified_at)}
                    </Typography>
                    <Typography variant="body2">
                      Qualifying Rosaries retained anonymously:{' '}
                      {preview.anonymousRosaryContribution}
                    </Typography>
                  </Box>
                  <Tabs
                    value={section}
                    variant="scrollable"
                    onChange={(_, value: Section) => {
                      setSection(value);
                      setOffset(0);
                    }}
                  >
                    {sections.map((item) => (
                      <Tab
                        key={item.value}
                        value={item.value}
                        label={`${item.label} (${preview.sections[item.value] ?? 0})`}
                      />
                    ))}
                  </Tabs>
                  {section === 'account' ? (
                    <Stack spacing={2}>
                      <Box>
                        <Typography fontWeight={700}>Profile</Typography>
                        <Box
                          component="pre"
                          sx={{
                            whiteSpace: 'pre-wrap',
                            overflowWrap: 'anywhere',
                            m: 0,
                          }}
                        >
                          {JSON.stringify(preview.profile, null, 2)}
                        </Box>
                      </Box>
                      <Box>
                        <Typography fontWeight={700}>
                          Notification preferences
                        </Typography>
                        <Box
                          component="pre"
                          sx={{
                            whiteSpace: 'pre-wrap',
                            overflowWrap: 'anywhere',
                            m: 0,
                          }}
                        >
                          {JSON.stringify(
                            preview.notificationPreferences,
                            null,
                            2,
                          )}
                        </Box>
                      </Box>
                    </Stack>
                  ) : (
                    <Stack spacing={1}>
                      {preview.records.length === 0 ? (
                        <Alert severity="info">No records in this group.</Alert>
                      ) : (
                        preview.records.map((item, index) => (
                          <Card
                            variant="outlined"
                            key={`${item.recordType}-${item.occurredAt}-${index}`}
                          >
                            <CardContent>
                              <Typography fontWeight={700}>
                                {item.recordType}
                              </Typography>
                              <Typography variant="caption">
                                {formatDate(item.occurredAt)}
                              </Typography>
                              <Box
                                component="pre"
                                sx={{
                                  whiteSpace: 'pre-wrap',
                                  overflowWrap: 'anywhere',
                                  m: 1,
                                }}
                              >
                                {JSON.stringify(item.record, null, 2)}
                              </Box>
                            </CardContent>
                          </Card>
                        ))
                      )}
                      <Pagination
                        offset={offset}
                        hasMore={Boolean(previewMeta.hasMore)}
                        onPrevious={() =>
                          setOffset((current) => Math.max(0, current - 25))
                        }
                        onNext={() => setOffset((current) => current + 25)}
                      />
                    </Stack>
                  )}
                  {!preview.isProtectedAdmin && (
                    <>
                      <Divider />
                      <Alert severity="error">
                        This removes the Auth identity and linked application
                        data. It cannot be undone.
                      </Alert>
                      <TextField
                        label="Confirmation"
                        value={confirmation}
                        onChange={(event) =>
                          setConfirmation(event.target.value)
                        }
                        helperText={`Type DELETE ${preview.account.id} to enable permanent deletion.`}
                      />
                    </>
                  )}
                </Stack>
              ) : null}
            </DialogContent>
            <DialogActions>
              <Button disabled={state === 'submitting'} onClick={closePreview}>
                Cancel
              </Button>
              {!preview?.isProtectedAdmin && (
                <Button
                  color="error"
                  variant="contained"
                  disabled={
                    !preview ||
                    confirmation !== `DELETE ${preview.account.id}` ||
                    state === 'submitting'
                  }
                  onClick={() => void remove()}
                >
                  {state === 'submitting' ? 'Deleting…' : 'Permanently delete'}
                </Button>
              )}
            </DialogActions>
          </Dialog>
        )}
      </Stack>
    </Panel>
  );
}

export default function AdminManagementCards({
  accessToken,
}: {
  accessToken: string;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [active, setActive] = useState<
    | 'analytics'
    | 'email'
    | 'contacts'
    | 'events'
    | 'prayers'
    | 'examination'
    | 'churches'
    | 'deletion'
  >('analytics');
  const requestedPanel = searchParams.get('panel');

  useEffect(() => {
    if (
      requestedPanel === 'analytics' ||
      requestedPanel === 'email' ||
      requestedPanel === 'contacts' ||
      requestedPanel === 'events' ||
      requestedPanel === 'prayers' ||
      requestedPanel === 'examination' ||
      requestedPanel === 'churches' ||
      requestedPanel === 'deletion'
    ) {
      setActive(requestedPanel);
    }
  }, [requestedPanel]);

  function closeActivePanel() {
    setActive('analytics');
    if (requestedPanel) router.replace('/dashboard?tab=admin');
  }

  return (
    <>
      <Tabs
        aria-label="Admin Center sections"
        onChange={(_event, value) => setActive(value)}
        sx={{ mt: 3 }}
        value={active}
        variant="scrollable"
        allowScrollButtonsMobile
      >
        <Tab label="Analytics" value="analytics" />
        <Tab label="Email Center" value="email" />
        <Tab label="Contact Requests" value="contacts" />
        <Tab label="Events" value="events" />
        <Tab label="Prayer Intentions" value="prayers" />
        <Tab label="Examination Content" value="examination" />
        <Tab label="Church Changes" value="churches" />
        <Tab label="User Deletion" value="deletion" />
      </Tabs>
      {active === 'analytics' && (
        <Panel title="App Analytics" onClose={closeActivePanel}>
          <AdminAppMetrics accessToken={accessToken} />
        </Panel>
      )}
      {active === 'email' && (
        <Panel title="Email Center" onClose={closeActivePanel}>
          <EmailCenter token={accessToken} />
        </Panel>
      )}
      {active === 'contacts' && (
        <ContactRequestsPanel token={accessToken} onClose={closeActivePanel} />
      )}
      {active === 'events' && (
        <AdminEventsPanel token={accessToken} onClose={closeActivePanel} />
      )}
      {active === 'prayers' && (
        <PrayerIntentionsPanel token={accessToken} onClose={closeActivePanel} />
      )}
      {active === 'examination' && (
        <ExaminationPanel token={accessToken} onClose={closeActivePanel} />
      )}
      {active === 'churches' && (
        <ChurchRequestsPanel token={accessToken} onClose={closeActivePanel} />
      )}
      {active === 'deletion' && (
        <UserDeletionPanel token={accessToken} onClose={closeActivePanel} />
      )}
    </>
  );
}
