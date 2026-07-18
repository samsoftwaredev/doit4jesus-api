import type { ReactNode } from 'react'

export const metadata = {
  title: 'Holy Competition API',
  description: 'Next.js API backed by Supabase Auth and PostgreSQL.',
}

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
