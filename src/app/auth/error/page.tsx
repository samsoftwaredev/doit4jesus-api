import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Container from '@mui/material/Container';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import NextLink from 'next/link';

export default function AuthErrorPage() {
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
          <Typography fontSize="2.5rem" mb={1}>
            ⚠️
          </Typography>
          <Typography variant="h5" fontWeight={700} mb={1}>
            Authentication Error
          </Typography>
          <Typography color="text.secondary" mb={3}>
            The link you used is invalid or has expired. Please request a new
            one.
          </Typography>
          <Stack spacing={1.5}>
            <Button
              component={NextLink}
              href="/auth/login"
              variant="contained"
              size="large"
            >
              Back to Sign In
            </Button>
            <Button
              component={NextLink}
              href="/auth/forgot-password"
              variant="outlined"
              size="large"
            >
              Reset Password
            </Button>
          </Stack>
        </Paper>
      </Container>
    </Box>
  );
}
