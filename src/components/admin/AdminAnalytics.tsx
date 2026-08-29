'use client';

import Alert from '@mui/material/Alert';
import Container from '@mui/material/Container';
import Skeleton from '@mui/material/Skeleton';
import Typography from '@mui/material/Typography';
import { useEffect, useState } from 'react';

import { supabaseClient } from '@/app/classes/supabaseClient';

import AdminAppMetrics from './AdminAppMetrics';

export default function AdminAnalytics() {
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [sessionResolved, setSessionResolved] = useState(false);

  useEffect(() => {
    supabaseClient.auth.getSession().then(({ data }) => {
      setAccessToken(data.session?.access_token ?? null);
      setSessionResolved(true);
    });

    const {
      data: { subscription },
    } = supabaseClient.auth.onAuthStateChange((_event, session) => {
      setAccessToken(session?.access_token ?? null);
      setSessionResolved(true);
    });

    return () => subscription.unsubscribe();
  }, []);

  return (
    <Container maxWidth="xl" sx={{ py: 3 }}>
      <Typography component="h1" variant="h4" fontWeight={700}>
        Admin Analytics
      </Typography>
      <Typography variant="body1" color="text.secondary" mt={0.5}>
        Privacy-preserving, aggregate product health metrics.
      </Typography>

      {!sessionResolved && <Skeleton sx={{ mt: 3 }} height={420} />}
      {sessionResolved && !accessToken && (
        <Alert severity="warning" sx={{ mt: 3 }}>
          Sign in with an administrator account to view app analytics.
        </Alert>
      )}
      {accessToken && <AdminAppMetrics accessToken={accessToken} />}
    </Container>
  );
}
