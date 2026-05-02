import Link from 'next/link'
import { usePathname } from 'next/navigation'

const TABS = [
  { href: '/', label: 'HOME', icon: '🏠' },
  { href: '/games', label: 'GAMES', icon: '🕹️' },
  { href: '/contact', label: 'CONTACT', icon: '📧' },
  { href: '/login', label: 'SIGN IN', icon: '👤' },
] as const

interface BottomTabBarProps {
  hideOn?: string[]
}

export function BottomTabBar({ hideOn = [] }: BottomTabBarProps) {
  const pathname = usePathname()

  if (hideOn.includes(pathname)) return null

  const isActive = (href: string) => {
    if (href === '/') return pathname === '/'
    return pathname.startsWith(href)
  }

  return (
    <>
      {/* Mobile: fixed bottom bar */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-50 flex justify-around py-3 px-2"
           style={{ background: 'rgba(90,58,31,0.96)' }}>
        {TABS.map((tab) => {
          const active = isActive(tab.href)
          return (
            <Link key={tab.href} href={tab.href} className="flex flex-col items-center gap-0.5 min-w-[64px] min-h-[48px] justify-center">
              <span className="text-2xl" style={{ opacity: active ? 1 : 0.5 }}>{tab.icon}</span>
              <span
                className="font-pixel text-xs font-semibold"
                style={{ color: active ? '#f4d03f' : 'rgba(244,208,63,0.45)' }}
              >
                {tab.label}
              </span>
            </Link>
          )
        })}
      </nav>

      {/* Desktop: centered top bar */}
      <nav className="hidden md:flex justify-center gap-8 py-4 px-4"
           style={{ background: 'rgba(90,58,31,0.96)' }}>
        {TABS.map((tab) => {
          const active = isActive(tab.href)
          return (
            <Link key={tab.href} href={tab.href} className="flex items-center gap-2 px-4 py-2 min-h-[48px]">
              <span className="text-xl" style={{ opacity: active ? 1 : 0.5 }}>{tab.icon}</span>
              <span
                className="font-pixel text-sm font-semibold"
                style={{ color: active ? '#f4d03f' : 'rgba(244,208,63,0.45)' }}
              >
                {tab.label}
              </span>
            </Link>
          )
        })}
      </nav>
    </>
  )
}
