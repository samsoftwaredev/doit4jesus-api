import AnalyticsOutlinedIcon from '@mui/icons-material/AnalyticsOutlined';
import CodeOutlinedIcon from '@mui/icons-material/CodeOutlined';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Container from '@mui/material/Container';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';

export default function DashboardPage() {
  return (
    <Container maxWidth="lg" sx={{ py: 3 }}>
      <Stack spacing={0.5} mb={3}>
        <Typography component="h1" variant="h4" fontWeight={700}>
          Dashboard
        </Typography>
        <Typography color="text.secondary">
          Choose the workspace you need.
        </Typography>
      </Stack>

      <Box
        display="grid"
        gridTemplateColumns="repeat(auto-fit, minmax(260px, 1fr))"
        gap={3}
      >
        <Card component="section" variant="outlined">
          <CardContent>
            <Stack spacing={2} alignItems="flex-start">
              <CodeOutlinedIcon color="primary" fontSize="large" />
              <Box>
                <Typography component="h2" variant="h6" fontWeight={700}>
                  Developer Tools
                </Typography>
                <Typography variant="body2" color="text.secondary" mt={0.5}>
                  View your bearer token, API status, and current profile.
                </Typography>
              </Box>
              <Button href="/dashboard/developer" variant="contained">
                Open Developer Tools
              </Button>
            </Stack>
          </CardContent>
        </Card>

        <Card component="section" variant="outlined">
          <CardContent>
            <Stack spacing={2} alignItems="flex-start">
              <AnalyticsOutlinedIcon color="primary" fontSize="large" />
              <Box>
                <Typography component="h2" variant="h6" fontWeight={700}>
                  Admin Analytics
                </Typography>
                <Typography variant="body2" color="text.secondary" mt={0.5}>
                  Review aggregate growth, activation, retention, and Rosary
                  practice trends.
                </Typography>
              </Box>
              <Button href="/dashboard/admin" variant="outlined">
                Open Admin Analytics
              </Button>
            </Stack>
          </CardContent>
        </Card>
      </Box>
    </Container>
  );
}
