'use client';

import Container from '@mui/material/Container';
import Tab from '@mui/material/Tab';
import Tabs from '@mui/material/Tabs';
import Typography from '@mui/material/Typography';
import { useRouter, useSearchParams } from 'next/navigation';

import AdminAnalytics from '@/components/admin/AdminAnalytics';
import DeveloperTools from '@/components/developer/DeveloperTools';

type DashboardTab = 'admin' | 'developer';

function selectedTab(value: string | null): DashboardTab {
  return value === 'developer' ? 'developer' : 'admin';
}

export default function DashboardTabs() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const activeTab = selectedTab(searchParams.get('tab'));

  function selectTab(_event: React.SyntheticEvent, value: DashboardTab) {
    router.replace(`/dashboard?tab=${value}`);
  }

  return (
    <>
      <Container maxWidth="xl" sx={{ pt: 3 }}>
        <Typography component="h1" variant="h4" fontWeight={700}>
          Dashboard
        </Typography>
        <Tabs
          aria-label="Dashboard workspaces"
          onChange={selectTab}
          sx={{ mt: 2 }}
          value={activeTab}
        >
          <Tab label="Admin Center" value="admin" />
          <Tab label="Developer Tools" value="developer" />
        </Tabs>
      </Container>
      {activeTab === 'admin' ? <AdminAnalytics /> : <DeveloperTools />}
    </>
  );
}
