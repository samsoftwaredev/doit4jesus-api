'use client'

import { useEffect, useState } from 'react'
import Box from '@mui/material/Box'
import Card from '@mui/material/Card'
import CardContent from '@mui/material/CardContent'
import Container from '@mui/material/Container'
import IconButton from '@mui/material/IconButton'
import InputAdornment from '@mui/material/InputAdornment'
import TextField from '@mui/material/TextField'
import Tooltip from '@mui/material/Tooltip'
import Typography from '@mui/material/Typography'
import ContentCopyIcon from '@mui/icons-material/ContentCopy'
import CheckIcon from '@mui/icons-material/Check'
import { supabaseClient } from '@/app/classes/supabaseClient'

export default function DashboardPage() {
  const [token, setToken] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    supabaseClient.auth.getSession().then(({ data }) => {
      setToken(data.session?.access_token ?? null)
    })

    const { data: { subscription } } = supabaseClient.auth.onAuthStateChange((_event, session) => {
      setToken(session?.access_token ?? null)
    })

    return () => subscription.unsubscribe()
  }, [])

  async function handleCopy() {
    if (!token) return
    await navigator.clipboard.writeText(token)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <Container maxWidth="lg" sx={{ py: 3 }}>
      <Typography variant="h4" fontWeight={700} mb={3}>Dashboard</Typography>

      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={700} mb={1.5}>
            Bearer Token
          </Typography>
          <Typography variant="body2" color="text.secondary" mb={2}>
            Use this token in the <code>Authorization: Bearer</code> header when calling the API (e.g. Postman).
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
                  sx: { fontFamily: 'monospace', fontSize: '0.75rem', wordBreak: 'break-all' },
                  endAdornment: token ? (
                    <InputAdornment position="end" sx={{ alignSelf: 'flex-start', mt: 1 }}>
                      <Tooltip title={copied ? 'Copied!' : 'Copy token'}>
                        <IconButton size="small" onClick={handleCopy}>
                          {copied ? <CheckIcon fontSize="small" color="success" /> : <ContentCopyIcon fontSize="small" />}
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
    </Container>
  )
}
