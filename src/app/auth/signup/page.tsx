'use client';

import Alert from '@mui/material/Alert';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Container from '@mui/material/Container';
import Link from '@mui/material/Link';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import NextLink from 'next/link';
import { useState } from 'react';

import { supabaseClient } from '@/app/classes/supabaseClient';

export default function SignupPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (password !== confirm) {
      setError('Passwords do not match.');
      return;
    }

    setLoading(true);
    setError(null);

    const { error } = await supabaseClient.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    });

    if (error) {
      setError(error.message);
      setLoading(false);
      return;
    }

    setSuccess(true);
    setLoading(false);
  }

  if (success) {
    return (
      <Box
        sx={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          bgcolor: 'background.default',
        }}
      >
        <Container maxWidth="xs">
          <Paper sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="h5" fontWeight={700} mb={2}>
              Check your email
            </Typography>
            <Typography color="text.secondary" mb={3}>
              We sent a confirmation link to <strong>{email}</strong>. Click the
              link to activate your account.
            </Typography>
            <Link component={NextLink} href="/auth/login" variant="body2">
              Back to Sign In
            </Link>
          </Paper>
        </Container>
      </Box>
    );
  }

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        bgcolor: 'background.default',
      }}
    >
      <Container maxWidth="xs">
        <Paper sx={{ p: 4 }}>
          <Typography variant="h5" fontWeight={700} textAlign="center" mb={3}>
            Create Account
          </Typography>
          <Stack component="form" onSubmit={handleSubmit} spacing={2}>
            <TextField
              placeholder="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
            <TextField
              placeholder="Password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              inputProps={{ minLength: 8 }}
              autoComplete="new-password"
            />
            <TextField
              placeholder="Confirm Password"
              type="password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              required
              inputProps={{ minLength: 8 }}
              autoComplete="new-password"
            />
            {error && <Alert severity="error">{error}</Alert>}
            <Button
              type="submit"
              variant="contained"
              size="large"
              loading={loading}
            >
              Create Account
            </Button>
          </Stack>
          <Stack mt={2} alignItems="center">
            <Typography variant="body2" color="text.secondary">
              Already have an account?{' '}
              <Link component={NextLink} href="/auth/login">
                Sign in
              </Link>
            </Typography>
          </Stack>
        </Paper>
      </Container>
    </Box>
  );
}
