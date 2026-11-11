'use client';

import Box from '@mui/material/Box';
import Tab from '@mui/material/Tab';
import Tabs from '@mui/material/Tabs';
import { useRouter, useSearchParams } from 'next/navigation';
import type { ReactNode } from 'react';

import AddChurchPanel from './AddChurchPanel';
import ChurchScheduleReviewsPanel from './ChurchScheduleReviewsPanel';

type ChurchView = 'changes' | 'schedules' | 'add';

function parseView(value: string | null): ChurchView {
  return value === 'schedules' || value === 'add' ? value : 'changes';
}

export default function ChurchesAdminPanel({
  token,
  onClose,
  changeRequests,
}: {
  token: string;
  onClose: () => void;
  changeRequests: ReactNode;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const active = parseView(searchParams.get('churchView'));

  function selectView(_event: React.SyntheticEvent, value: ChurchView) {
    router.replace(`/dashboard?tab=admin&panel=churches&churchView=${value}`);
  }

  return (
    <Box>
      <Tabs
        aria-label="Church administration sections"
        value={active}
        onChange={selectView}
        sx={{ mt: 2 }}
      >
        <Tab label="Change Requests" value="changes" />
        <Tab label="Schedule Reviews" value="schedules" />
        <Tab label="Add Church" value="add" />
      </Tabs>
      {active === 'changes' && changeRequests}
      {active === 'schedules' && (
        <ChurchScheduleReviewsPanel token={token} onClose={onClose} />
      )}
      {active === 'add' && <AddChurchPanel token={token} />}
    </Box>
  );
}
