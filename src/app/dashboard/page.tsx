import { Suspense } from 'react';

import DashboardTabs from '@/components/dashboard/DashboardTabs';

export default function DashboardPage() {
  return (
    <Suspense>
      <DashboardTabs />
    </Suspense>
  );
}
