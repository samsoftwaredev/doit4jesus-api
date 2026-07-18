import type { ReactNode } from 'react'
import ThemeRegistry from '@/lib/theme/ThemeRegistry'
import { UserProvider } from '@/context/UserContext'

export const metadata = {
  title: 'DoIt4Jesus',
  description: 'Next.js API backed by Supabase Auth and PostgreSQL.',
}

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <ThemeRegistry>
          <UserProvider>{children}</UserProvider>
        </ThemeRegistry>
      </body>
    </html>
  )
}
