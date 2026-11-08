'use client';

import Box from '@mui/material/Box';
import Tab from '@mui/material/Tab';
import Tabs from '@mui/material/Tabs';
import { useRouter, useSearchParams } from 'next/navigation';
import type { ReactNode } from 'react';

import ChurchScheduleReviewsPanel from './ChurchScheduleReviewsPanel';

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
  const active =
    searchParams.get('churchView') === 'schedules' ? 'schedules' : 'changes';

  function selectView(
    _event: React.SyntheticEvent,
    value: 'changes' | 'schedules',
  ) {
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
      </Tabs>
      {active === 'changes' ? (
        changeRequests
      ) : (
        <ChurchScheduleReviewsPanel token={token} onClose={onClose} />
      )}
    </Box>
  );
}
