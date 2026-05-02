import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { BottomTabBar } from '../BottomTabBar'

vi.mock('next/navigation', () => ({
  usePathname: () => '/',
}))

describe('BottomTabBar', () => {
  it('renders all 4 tabs', () => {
    render(<BottomTabBar />)
    expect(screen.getAllByText('HOME')).toHaveLength(2)
    expect(screen.getAllByText('GAMES')).toHaveLength(2)
    expect(screen.getAllByText('CONTACT')).toHaveLength(2)
    expect(screen.getAllByText('SIGN IN')).toHaveLength(2)
  })

  it('hides when current path is in hideOn', () => {
    const { container } = render(<BottomTabBar hideOn={['/']} />)
    expect(container.firstChild).toBeNull()
  })
})
