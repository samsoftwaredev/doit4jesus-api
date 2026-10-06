'use client';

import AnalyticsOutlinedIcon from '@mui/icons-material/AnalyticsOutlined';
import ChurchOutlinedIcon from '@mui/icons-material/ChurchOutlined';
import ContactMailOutlinedIcon from '@mui/icons-material/ContactMailOutlined';
import DeleteForeverOutlinedIcon from '@mui/icons-material/DeleteForeverOutlined';
import FactCheckOutlinedIcon from '@mui/icons-material/FactCheckOutlined';
import FavoriteBorderOutlinedIcon from '@mui/icons-material/FavoriteBorderOutlined';
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
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import { useRouter, useSearchParams } from 'next/navigation';
import { type ReactNode, useCallback, useEffect, useState } from 'react';

import { contactSubjectValues } from '@/lib/schemas/contact';

import AdminAppMetrics from './AdminAppMetrics';

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

function ManagementCard({
  icon,
  title,
  description,
  action,
  onClick,
  destructive = false,
}: {
  icon: ReactNode;
  title: string;
  description: string;
  action: string;
  onClick: () => void;
  destructive?: boolean;
}) {
  return (
    <Card component="section" variant="outlined">
      <CardContent>
        <Stack spacing={2} alignItems="flex-start">
          <Box color={destructive ? 'error.main' : 'primary.main'}>{icon}</Box>
          <Box>
            <Typography component="h2" variant="h6" fontWeight={700}>
              {title}
            </Typography>
            <Typography variant="body2" color="text.secondary" mt={0.5}>
              {description}
            </Typography>
          </Box>
          <Button
            color={destructive ? 'error' : 'primary'}
            onClick={onClick}
            variant="outlined"
          >
            {action}
          </Button>
        </Stack>
      </CardContent>
    </Card>
  );
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
    <Dialog open onClose={onClose} fullWidth maxWidth="md">
      <DialogTitle>{title}</DialogTitle>
      <DialogContent dividers>{children}</DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
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

  return (
    <Panel title="Contact Requests" onClose={onClose}>
      <Stack spacing={2}>
        <Alert severity="info">
          This inbox is read-only. Contact-request statuses cannot be changed
          through the current API.
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
                    <Button onClick={() => setSelected(item)}>
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
              <Stack spacing={1}>
                <Typography variant="body2">
                  From: {selected.name} &lt;{selected.email}&gt;
                </Typography>
                <Typography whiteSpace="pre-wrap">
                  {selected.message}
                </Typography>
              </Stack>
            </DialogContent>
            <DialogActions>
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
  const [userId, setUserId] = useState('');
  const [confirming, setConfirming] = useState(false);
  const [confirmation, setConfirmation] = useState('');
  const [state, setState] = useState<
    'idle' | 'submitting' | 'success' | 'error'
  >('idle');
  const [error, setError] = useState('');
  async function remove() {
    setState('submitting');
    try {
      await adminFetch(token, `/api/v1/admin/users/${userId}`, {
        method: 'DELETE',
      });
      setState('success');
      setConfirming(false);
      setConfirmation('');
      setUserId('');
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
        <TextField
          label="User UUID"
          required
          value={userId}
          onChange={(event) => {
            setUserId(event.target.value);
            setState('idle');
          }}
          helperText="Paste the exact user UUID. There is no user lookup in this tool."
        />
        <Button
          color="error"
          variant="contained"
          disabled={!userId}
          onClick={() => setConfirming(true)}
        >
          Delete account
        </Button>
        {confirming && (
          <Dialog open onClose={() => setConfirming(false)}>
            <DialogTitle>Confirm permanent deletion</DialogTitle>
            <DialogContent>
              <Stack spacing={2} pt={1}>
                <Typography>
                  To permanently delete user{' '}
                  <Box component="code">{userId}</Box>, type{' '}
                  <Box component="strong">DELETE</Box>.
                </Typography>
                <TextField
                  autoFocus
                  label="Confirmation"
                  value={confirmation}
                  onChange={(event) => setConfirmation(event.target.value)}
                />
              </Stack>
            </DialogContent>
            <DialogActions>
              <Button onClick={() => setConfirming(false)}>Cancel</Button>
              <Button
                color="error"
                variant="contained"
                disabled={confirmation !== 'DELETE' || state === 'submitting'}
                onClick={() => void remove()}
              >
                {state === 'submitting' ? 'Deleting…' : 'Permanently delete'}
              </Button>
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
    | 'contacts'
    | 'prayers'
    | 'examination'
    | 'churches'
    | 'deletion'
    | null
  >(null);
  const requestedPanel = searchParams.get('panel');

  useEffect(() => {
    if (
      requestedPanel === 'contacts' ||
      requestedPanel === 'prayers' ||
      requestedPanel === 'churches'
    ) {
      setActive(requestedPanel);
    }
  }, [requestedPanel]);

  function closeActivePanel() {
    setActive(null);
    if (requestedPanel) router.replace('/dashboard/admin');
  }

  return (
    <>
      <Box
        display="grid"
        gridTemplateColumns="repeat(auto-fit, minmax(260px, 1fr))"
        gap={3}
        mt={3}
      >
        <ManagementCard
          icon={<AnalyticsOutlinedIcon fontSize="large" />}
          title="App Analytics"
          description="Review aggregate growth, engagement, retention, and Rosary practice metrics."
          action="View analytics"
          onClick={() => setActive('analytics')}
        />
        <ManagementCard
          icon={<ContactMailOutlinedIcon fontSize="large" />}
          title="Contact Requests"
          description="Search and read support, feedback, and partnership inquiries."
          action="Open inbox"
          onClick={() => setActive('contacts')}
        />
        <ManagementCard
          icon={<FavoriteBorderOutlinedIcon fontSize="large" />}
          title="Prayer Intentions"
          description="Review community prayer requests and approve or reject pending submissions."
          action="Review intentions"
          onClick={() => setActive('prayers')}
        />
        <ManagementCard
          icon={<FactCheckOutlinedIcon fontSize="large" />}
          title="Examination Content"
          description="Create, edit, activate, and remove examination-of-conscience questions."
          action="Manage questions"
          onClick={() => setActive('examination')}
        />
        <ManagementCard
          icon={<ChurchOutlinedIcon fontSize="large" />}
          title="Church Change Requests"
          description="Review submitted church and service-schedule changes."
          action="Review changes"
          onClick={() => setActive('churches')}
        />
        <ManagementCard
          icon={<DeleteForeverOutlinedIcon fontSize="large" />}
          title="User Account Deletion"
          description="Permanently remove a specified user account and associated application data."
          action="Delete user"
          destructive
          onClick={() => setActive('deletion')}
        />
      </Box>
      {active === 'analytics' && (
        <Panel title="App Analytics" onClose={closeActivePanel}>
          <AdminAppMetrics accessToken={accessToken} />
        </Panel>
      )}
      {active === 'contacts' && (
        <ContactRequestsPanel token={accessToken} onClose={closeActivePanel} />
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
