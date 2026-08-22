'use client';

import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import CircularProgress from '@mui/material/CircularProgress';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

import { useUser } from '@/context/UserContext';

export default function HomePage() {
  const router = useRouter();
  const { user, isLoading } = useUser();

  useEffect(() => {
    if (!isLoading && user) router.push('/dashboard');
  }, [isLoading, user, router]);

  if (isLoading) {
    return (
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box
      component="main"
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Stack alignItems="center" spacing={3}>
        <Typography variant="h3" component="h1" fontWeight={700}>
          Holy Competition
        </Typography>
        <Stack direction="row" spacing={2}>
          <Button variant="contained" size="large" href="/auth/login">
            Sign In
          </Button>
          <Button variant="outlined" size="large" href="/auth/signup">
            Create Account
          </Button>
        </Stack>
      </Stack>
    </Box>
  );
}
