import type { ReactNode } from 'react';

import TopNav from '@/components/TopNav';
import { UserProvider } from '@/context/UserContext';
import ThemeRegistry from '@/theme/ThemeRegistry';

export const metadata = {
  title: 'DoIt4Jesus',
  description: 'Next.js API backed by Supabase Auth and PostgreSQL.',
};

export default function RootLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <ThemeRegistry>
          <UserProvider>
            <TopNav />
            {children}
          </UserProvider>
        </ThemeRegistry>
      </body>
    </html>
  );
}
