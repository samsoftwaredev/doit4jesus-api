'use client'

import { useState } from 'react'
import NextLink from 'next/link'
import Alert from '@mui/material/Alert'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Container from '@mui/material/Container'
import Link from '@mui/material/Link'
import Paper from '@mui/material/Paper'
import Stack from '@mui/material/Stack'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import { supabaseClient } from '@/app/classes/supabaseClient'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)

    const { error } = await supabaseClient.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?type=recovery`,
    })

    if (error) {
      setError(error.message)
      setLoading(false)
      return
    }

    setSuccess(true)
    setLoading(false)
  }

  if (success) {
    return (
      <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', bgcolor: 'background.default' }}>
        <Container maxWidth="xs">
          <Paper sx={{ p: 4, textAlign: 'center' }}>
            <Typography variant="h5" fontWeight={700} mb={2}>Check your email</Typography>
            <Typography color="text.secondary" mb={3}>
              If <strong>{email}</strong> is registered, you will receive a password reset link shortly.
            </Typography>
            <Link component={NextLink} href="/auth/login" variant="body2">Back to Sign In</Link>
          </Paper>
        </Container>
      </Box>
    )
  }

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', bgcolor: 'background.default' }}>
      <Container maxWidth="xs">
        <Paper sx={{ p: 4 }}>
          <Typography variant="h5" fontWeight={700} textAlign="center" mb={0.5}>
            Forgot Password
          </Typography>
          <Typography variant="body2" color="text.secondary" textAlign="center" mb={3}>
            Enter your email and we&apos;ll send you a reset link.
          </Typography>
          <Stack component="form" onSubmit={handleSubmit} spacing={2}>
            <TextField
              label="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
            {error && <Alert severity="error">{error}</Alert>}
            <Button type="submit" variant="contained" size="large" loading={loading}>
              Send Reset Link
            </Button>
          </Stack>
          <Stack mt={2} alignItems="center">
            <Link component={NextLink} href="/auth/login" variant="body2">Back to Sign In</Link>
          </Stack>
        </Paper>
      </Container>
    </Box>
  )
}

