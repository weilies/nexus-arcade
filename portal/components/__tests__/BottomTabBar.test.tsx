import { describe, it, expect, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { BottomTabBar } from '../BottomTabBar'

let mockUser: { id: string; email: string; user_metadata: Record<string, string> } | null = null

vi.mock('next/navigation', () => ({
  usePathname: () => '/',
}))

vi.mock('@/lib/supabase/browser', () => ({
  createClient: () => ({
    auth: {
      getUser: () => Promise.resolve({ data: { user: mockUser } }),
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
  it('renders nav tabs and sign in when logged out', () => {
    mockUser = null
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
    mockUser = null
    render(<BottomTabBar />)
    expect(screen.queryByText('ADMIN')).toBeNull()
  })

  it('shows SIGN OUT when user is signed in', async () => {
    mockUser = { id: '123', email: 'test@example.com', user_metadata: { full_name: 'Test User' } }
    render(<BottomTabBar />)
    await waitFor(() => {
      expect(screen.getAllByText('SIGN OUT')).toHaveLength(2)
    })
    mockUser = null
  })
})
