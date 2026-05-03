'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { useEffect, useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/browser'
import type { User } from '@supabase/supabase-js'

const NAV_TABS = [
  { href: '/', label: 'HOME', icon: '🏠' },
  { href: '/games', label: 'GAMES', icon: '🕹️' },
] as const

interface BottomTabBarProps {
  hideOn?: string[]
}

export function BottomTabBar({ hideOn = [] }: BottomTabBarProps) {
  const pathname = usePathname()
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const supabase = createClient()

    supabase.auth.getUser().then(async ({ data }) => {
      setUser(data.user)
      if (data.user) {
        const { data: role } = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', data.user.id)
          .eq('role', 'platform_admin')
          .maybeSingle()
        setIsAdmin(!!role)
      }
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, session) => {
      const u = session?.user ?? null
      setUser(u)
      if (u) {
        const { data: role } = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', u.id)
          .eq('role', 'platform_admin')
          .maybeSingle()
        setIsAdmin(!!role)
      } else {
        setIsAdmin(false)
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false)
      }
    }
    if (menuOpen) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [menuOpen])

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/')
    router.refresh()
  }

  if (hideOn.includes(pathname)) return null

  const isActive = (href: string) => {
    if (href === '/') return pathname === '/'
    return pathname.startsWith(href)
  }

  const authLabel = user
    ? (user.user_metadata?.full_name?.split(' ')[0] ?? user.email?.split('@')[0] ?? 'ME')
    : 'SIGN IN'

  const barBg = 'rgba(10,10,26,0.96)'
  const barBorder = 'rgba(42,42,74,0.6)'

  return (
    <>
      {/* Mobile: sticky top header with hamburger */}
      <header
        className="md:hidden sticky top-0 z-50 flex items-center gap-3 px-4 py-3 backdrop-blur border-b"
        style={{ background: barBg, borderColor: barBorder }}
      >
        {/* Hamburger button */}
        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="flex flex-col gap-1 p-2 bg-transparent border-none cursor-pointer min-h-[48px] min-w-[48px]"
          aria-label="Toggle menu"
        >
          <span className="block w-5 h-0.5 rounded" style={{ background: menuOpen ? 'var(--neon-cyan)' : '#8888aa' }} />
          <span className="block w-5 h-0.5 rounded" style={{ background: menuOpen ? 'var(--neon-cyan)' : '#8888aa' }} />
          <span className="block w-5 h-0.5 rounded" style={{ background: menuOpen ? 'var(--neon-cyan)' : '#8888aa' }} />
        </button>

        {/* Logo */}
        <Link href="/" className="font-pixel text-base font-bold flex-1" style={{ color: 'var(--neon-cyan)' }}>
          NEXUS ARCADE
        </Link>

        {/* Auth */}
        {user ? (
          <button
            onClick={handleSignOut}
            className="font-pixel text-xs font-semibold bg-transparent border-none cursor-pointer min-h-[48px] px-2"
            style={{ color: '#8888aa' }}
          >
            SIGN OUT
          </button>
        ) : (
          <Link
            href="/login"
            className="font-pixel text-xs font-semibold min-h-[48px] flex items-center px-2"
            style={{ color: '#8888aa' }}
          >
            SIGN IN
          </Link>
        )}
      </header>

      {/* Mobile: hamburger dropdown menu */}
      {menuOpen && (
        <div ref={menuRef} className="md:hidden fixed top-[57px] left-0 right-0 z-40 backdrop-blur border-b px-4 py-3"
             style={{ background: barBg, borderColor: barBorder }}>
          {NAV_TABS.map((tab) => {
            const active = isActive(tab.href)
            return (
              <Link
                key={tab.href}
                href={tab.href}
                onClick={() => setMenuOpen(false)}
                className="flex items-center gap-3 py-3 min-h-[48px]"
              >
                <span className="text-xl" style={{ opacity: active ? 1 : 0.4 }}>{tab.icon}</span>
                <span
                  className="font-pixel text-sm font-semibold"
                  style={{ color: active ? 'var(--neon-cyan)' : 'rgba(136,136,170,0.7)' }}
                >
                  {tab.label}
                </span>
              </Link>
            )
          })}
          {isAdmin && (
            <Link
              href="/admin"
              onClick={() => setMenuOpen(false)}
              className="flex items-center gap-3 py-3 min-h-[48px]"
            >
              <span className="text-xl">⚙️</span>
              <span
                className="font-pixel text-sm font-semibold"
                style={{ color: pathname.startsWith('/admin') ? 'var(--neon-magenta)' : 'rgba(136,136,170,0.7)' }}
              >
                ADMIN
              </span>
            </Link>
          )}
        </div>
      )}

      {/* Mobile: fixed bottom nav bar */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 z-50 flex justify-around py-3 px-2 backdrop-blur border-t"
           style={{ background: barBg, borderColor: barBorder }}>
        {NAV_TABS.map((tab) => {
          const active = isActive(tab.href)
          return (
            <Link key={tab.href} href={tab.href} className="flex flex-col items-center gap-0.5 min-w-[64px] min-h-[48px] justify-center">
              <span className="text-2xl" style={{ opacity: active ? 1 : 0.4 }}>{tab.icon}</span>
              <span
                className="font-pixel text-xs font-semibold"
                style={{ color: active ? 'var(--neon-cyan)' : 'rgba(136,136,170,0.5)' }}
              >
                {tab.label}
              </span>
            </Link>
          )
        })}
      </nav>

      {/* Desktop: centered top bar */}
      <nav className="hidden md:flex justify-center gap-8 py-4 px-4 backdrop-blur border-b"
           style={{ background: barBg, borderColor: barBorder }}>
        {NAV_TABS.map((tab) => {
          const active = isActive(tab.href)
          return (
            <Link key={tab.href} href={tab.href} className="flex items-center gap-2 px-4 py-2 min-h-[48px]">
              <span className="text-xl" style={{ opacity: active ? 1 : 0.4 }}>{tab.icon}</span>
              <span
                className="font-pixel text-sm font-semibold"
                style={{ color: active ? 'var(--neon-cyan)' : 'rgba(136,136,170,0.5)' }}
              >
                {tab.label}
              </span>
            </Link>
          )
        })}
        {isAdmin && (
          <Link href="/admin" className="flex items-center gap-2 px-4 py-2 min-h-[48px]">
            <span className="text-xl">⚙️</span>
            <span
              className="font-pixel text-sm font-semibold"
              style={{ color: pathname.startsWith('/admin') ? 'var(--neon-magenta)' : 'rgba(136,136,170,0.5)' }}
            >
              ADMIN
            </span>
          </Link>
        )}
        {user ? (
          <button
            onClick={handleSignOut}
            className="flex items-center gap-2 px-4 py-2 min-h-[48px] bg-transparent border-none cursor-pointer"
          >
            <span className="font-pixel text-sm font-semibold" style={{ color: '#8888aa' }}>
              SIGN OUT
            </span>
          </button>
        ) : (
          <Link href="/login" className="flex items-center gap-2 px-4 py-2 min-h-[48px]">
            <span className="font-pixel text-sm font-semibold" style={{ color: 'rgba(136,136,170,0.5)' }}>
              SIGN IN
            </span>
          </Link>
        )}
      </nav>
    </>
  )
}
