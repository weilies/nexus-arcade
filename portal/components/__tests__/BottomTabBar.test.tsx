import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { BottomTabBar } from '../BottomTabBar'

vi.mock('next/navigation', () => ({
  usePathname: () => '/',
  useRouter: () => ({ push: vi.fn(), refresh: vi.fn() }),
}))

vi.mock('@/lib/supabase/browser', () => ({
  createClient: () => ({
    auth: {
      getUser: () => Promise.resolve({ data: { user: null } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: vi.fn() } } }),
    },
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            maybeSingle: () => Promise.resolve({ data: null }),
          }),
        }),
      }),
    }),
  }),
}))

describe('BottomTabBar', () => {
  it('renders nav tabs and sign in', () => {
    render(<BottomTabBar />)
    expect(screen.getAllByText('HOME')).toHaveLength(2)
    expect(screen.getAllByText('GAMES')).toHaveLength(2)
    expect(screen.getAllByText('SIGN IN')).toHaveLength(2)
  })

  it('hides when current path is in hideOn', () => {
    const { container } = render(<BottomTabBar hideOn={['/']} />)
    expect(container.firstChild).toBeNull()
  })

  it('does not show admin link for non-admin users', () => {
    render(<BottomTabBar />)
    expect(screen.queryByText('ADMIN')).toBeNull()
  })
})
