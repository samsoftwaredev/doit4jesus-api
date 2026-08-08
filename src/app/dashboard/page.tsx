'use client';

import CheckIcon from '@mui/icons-material/Check';
import ContentCopyIcon from '@mui/icons-material/ContentCopy';
import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Container from '@mui/material/Container';
import IconButton from '@mui/material/IconButton';
import InputAdornment from '@mui/material/InputAdornment';
import TextField from '@mui/material/TextField';
import Tooltip from '@mui/material/Tooltip';
import Typography from '@mui/material/Typography';
import { useEffect, useState } from 'react';

import { supabaseClient } from '@/app/classes/supabaseClient';

type ServerStatus = 'loading' | 'ok' | 'error';

type MeProfile = Record<string, unknown> | null;

export default function DashboardPage() {
  const [token, setToken] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [serverStatus, setServerStatus] = useState<ServerStatus>('loading');
  const [meProfile, setMeProfile] = useState<MeProfile>(null);

  useEffect(() => {
    supabaseClient.auth.getSession().then(({ data }) => {
      setToken(data.session?.access_token ?? null);
    });

    const {
      data: { subscription },
    } = supabaseClient.auth.onAuthStateChange((_event, session) => {
      setToken(session?.access_token ?? null);
    });

    fetch('http://localhost:3000/api/v1/health', { method: 'GET' })
      .then((res) => res.json())
      .then((result) => {
        setServerStatus(result?.data?.status === 'ok' ? 'ok' : 'error');
      })
      .catch(() => setServerStatus('error'));

    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!token) return;
    const headers = new Headers();
    headers.append('Authorization', `Bearer ${token}`);
    fetch('http://localhost:3000/api/v1/me', { method: 'GET', headers })
      .then((res) => res.json())
      .then((result) => setMeProfile(result?.data ?? result))
      .catch(() => setMeProfile(null));
  }, [token]);

  async function handleCopy() {
    if (!token) return;
    await navigator.clipboard.writeText(token);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <Container maxWidth="lg" sx={{ py: 3 }}>
      <Box display="flex" alignItems="center" gap={1.5} mb={3}>
        <Typography variant="h4" fontWeight={700}>
          Dashboard
        </Typography>
        <Box display="flex" alignItems="center" gap={0.75}>
          <span
            style={{
              display: 'inline-block',
              width: 10,
              height: 10,
              borderRadius: '50%',
              backgroundColor:
                serverStatus === 'loading'
                  ? '#9e9e9e'
                  : serverStatus === 'ok'
                    ? '#4caf50'
                    : '#f44336',
              flexShrink: 0,
            }}
          />
          <Typography
            variant="caption"
            color={
              serverStatus === 'loading'
                ? 'text.secondary'
                : serverStatus === 'ok'
                  ? 'success.main'
                  : 'error.main'
            }
          >
            {serverStatus === 'loading'
              ? 'Checking server…'
              : serverStatus === 'ok'
                ? 'Server online'
                : 'Server offline'}
          </Typography>
        </Box>
      </Box>

      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={700} mb={1.5}>
            Bearer Token
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            Use this token in the <code>Authorization: Bearer</code> header when
            calling the API (e.g. Postman).
          </Typography>
          <Box position="relative">
            <TextField
              value={token ?? 'No active session'}
              fullWidth
              multiline
              minRows={3}
              maxRows={6}
              slotProps={{
                input: {
                  readOnly: true,
                  sx: {
                    fontFamily: 'monospace',
                    fontSize: '0.75rem',
                    wordBreak: 'break-all',
                  },
                  endAdornment: token ? (
                    <InputAdornment
                      position="end"
                      sx={{ alignSelf: 'flex-start', mt: 1 }}
                    >
                      <Tooltip title={copied ? 'Copied!' : 'Copy token'}>
                        <IconButton size="small" onClick={handleCopy}>
                          {copied ? (
                            <CheckIcon fontSize="small" color="success" />
                          ) : (
                            <ContentCopyIcon fontSize="small" />
                          )}
                        </IconButton>
                      </Tooltip>
                    </InputAdornment>
                  ) : null,
                },
              }}
            />
          </Box>
        </CardContent>
      </Card>

      {meProfile && (
        <Card sx={{ mt: 3 }}>
          <CardContent>
            <Typography variant="subtitle1" fontWeight={700} mb={1.5}>
              My Profile
            </Typography>
            <Box
              component="pre"
              sx={{
                fontFamily: 'monospace',
                fontSize: '0.75rem',
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-all',
                m: 0,
              }}
            >
              {JSON.stringify(meProfile, null, 2)}
            </Box>
          </CardContent>
        </Card>
      )}
    </Container>
  );
}
