import type { Metadata, Viewport } from 'next'
import './globals.css'
import { BottomTabBar } from '@/components/BottomTabBar'

export const metadata: Metadata = {
  title: 'Nexus Arcade',
  description: 'Casual games. Compete. Conquer.',
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen flex flex-col" style={{ background: '#5a3a1f' }}>
        <BottomTabBar hideOn={['/games/tictactoe']} />
        <main className="flex-1 pb-16 md:pb-0">
          {children}
        </main>
      </body>
    </html>
  )
}
