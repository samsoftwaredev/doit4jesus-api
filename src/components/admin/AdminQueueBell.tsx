'use client';

import NotificationsNoneOutlinedIcon from '@mui/icons-material/NotificationsNoneOutlined';
import Badge from '@mui/material/Badge';
import Box from '@mui/material/Box';
import Divider from '@mui/material/Divider';
import IconButton from '@mui/material/IconButton';
import Menu from '@mui/material/Menu';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import NextLink from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';

import { supabaseClient } from '@/app/classes/supabaseClient';

type ContactPreview = {
  id: string;
  name: string;
  subject: string;
  createdAt: string;
};
type PrayerIntentionPreview = { id: string; title: string; createdAt: string };
type ChurchChangePreview = {
  id: string;
  requestType: string;
  churchId: string | null;
  createdAt: string;
};
type Queue<T> = { count: number; items: T[] };
type Summary = {
  total: number;
  contacts: Queue<ContactPreview>;
  prayerIntentions: Queue<PrayerIntentionPreview>;
  churchChangeRequests: Queue<ChurchChangePreview>;
};
type SummaryResponse = {
  data?: Summary;
  error?: { message?: string };
};

function formatDate(value: string) {
  const date = new Date(value);
  return Number.isNaN(date.valueOf())
    ? value
    : new Intl.DateTimeFormat('en-US', { dateStyle: 'medium' }).format(date);
}

function QueueSection<T>({
  title,
  queue,
  panel,
  itemLabel,
  onNavigate,
}: {
  title: string;
  queue: Queue<T>;
  panel: 'contacts' | 'prayers' | 'churches';
  itemLabel: (item: T) => string;
  onNavigate: () => void;
}) {
  return (
    <Box component="section" aria-label={title}>
      <Stack
        direction="row"
        alignItems="baseline"
        justifyContent="space-between"
        px={2}
        pt={1.5}
        pb={0.5}
      >
        <Typography variant="subtitle2" fontWeight={700}>
          {title}
        </Typography>
        <Typography variant="caption" color="text.secondary">
          {queue.count} open
        </Typography>
      </Stack>
      {queue.items.length === 0 ? (
        <Typography variant="body2" color="text.secondary" px={2} py={1}>
          Nothing to review.
        </Typography>
      ) : (
        queue.items.map((item) => (
          <MenuItem
            component={NextLink}
            href={`/dashboard/admin?panel=${panel}`}
            key={(item as { id: string }).id}
            onClick={onNavigate}
            sx={{ alignItems: 'flex-start', py: 1 }}
          >
            <Box minWidth={0}>
              <Typography variant="body2" noWrap>
                {itemLabel(item)}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {formatDate((item as { createdAt: string }).createdAt)}
              </Typography>
            </Box>
          </MenuItem>
        ))
      )}
      <MenuItem
        component={NextLink}
        href={`/dashboard/admin?panel=${panel}`}
        onClick={onNavigate}
        sx={{
          color: 'primary.main',
          justifyContent: 'center',
          fontWeight: 600,
        }}
      >
        View all {title.toLowerCase()}
      </MenuItem>
    </Box>
  );
}

export default function AdminQueueBell() {
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [anchorEl, setAnchorEl] = useState<HTMLElement | null>(null);
  const refreshTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    supabaseClient.auth.getSession().then(({ data }) => {
      setAccessToken(data.session?.access_token ?? null);
    });
    const {
      data: { subscription },
    } = supabaseClient.auth.onAuthStateChange((_event, session) => {
      setAccessToken(session?.access_token ?? null);
    });
    return () => subscription.unsubscribe();
  }, []);

  const refresh = useCallback(async () => {
    if (!accessToken) {
      setSummary(null);
      setIsAdmin(false);
      return;
    }
    try {
      const response = await fetch('/api/v1/admin/notification-summary', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      const body = (await response.json()) as SummaryResponse;
      if (!response.ok || !body.data) {
        setSummary(null);
        setIsAdmin(false);
        return;
      }
      setSummary(body.data);
      setIsAdmin(true);
    } catch {
      setSummary(null);
      setIsAdmin(false);
    }
  }, [accessToken]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    if (!accessToken || !isAdmin) return;
    supabaseClient.realtime.setAuth(accessToken);
    const queueChannel = supabaseClient
      .channel('admin-queue-notification-summary')
      .on(
        'postgres_changes',
        { event: '*', schema: 'app', table: 'contact_requests' },
        scheduleRefresh,
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'prayer', table: 'prayer_intentions' },
        scheduleRefresh,
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'app', table: 'church_change_requests' },
        scheduleRefresh,
      )
      .subscribe();

    function scheduleRefresh() {
      if (refreshTimer.current) clearTimeout(refreshTimer.current);
      refreshTimer.current = setTimeout(() => {
        refreshTimer.current = null;
        void refresh();
      }, 250);
    }

    return () => {
      if (refreshTimer.current) clearTimeout(refreshTimer.current);
      void supabaseClient.removeChannel(queueChannel);
    };
  }, [accessToken, isAdmin, refresh]);

  if (!summary) return null;

  function closeMenu() {
    setAnchorEl(null);
  }

  return (
    <>
      <IconButton
        aria-label={`Admin queue notifications: ${summary.total} open`}
        onClick={(event) => setAnchorEl(event.currentTarget)}
        size="small"
      >
        <Badge badgeContent={summary.total} color="error" max={99}>
          <NotificationsNoneOutlinedIcon />
        </Badge>
      </IconButton>
      <Menu
        anchorEl={anchorEl}
        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
        open={Boolean(anchorEl)}
        onClose={closeMenu}
        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
        slotProps={{
          paper: {
            sx: { width: 340, maxWidth: 'calc(100vw - 24px)', mt: 0.5 },
          },
        }}
      >
        <QueueSection
          itemLabel={(item) => `${item.name}: ${item.subject}`}
          onNavigate={closeMenu}
          panel="contacts"
          queue={summary.contacts}
          title="Contact Requests"
        />
        <Divider />
        <QueueSection
          itemLabel={(item) => item.title}
          onNavigate={closeMenu}
          panel="prayers"
          queue={summary.prayerIntentions}
          title="Prayer Intentions"
        />
        <Divider />
        <QueueSection
          itemLabel={(item) =>
            item.requestType.replace('_', ' ') +
            (item.churchId ? ` · ${item.churchId}` : '')
          }
          onNavigate={closeMenu}
          panel="churches"
          queue={summary.churchChangeRequests}
          title="Church Change Requests"
        />
      </Menu>
    </>
  );
}
