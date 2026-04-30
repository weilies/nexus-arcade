import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'NEXUS ARCADE',
  description: 'Casual games. Compete. Conquer.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-arcade-bg antialiased">{children}</body>
    </html>
  )
}
