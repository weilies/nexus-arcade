import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { Nav } from '../Nav'

describe('Nav', () => {
  it('renders arcade title', () => {
    render(<Nav />)
    expect(screen.getByText('NEXUS ARCADE')).toBeDefined()
  })

  it('title links to homepage', () => {
    render(<Nav />)
    expect(
      screen.getByText('NEXUS ARCADE').closest('a')?.getAttribute('href')
    ).toBe('/')
  })

  it('renders leaderboard link', () => {
    render(<Nav />)
    expect(
      screen.getByText('LEADERBOARD').closest('a')?.getAttribute('href')
    ).toBe('/leaderboard')
  })

  it('renders login link', () => {
    render(<Nav />)
    expect(
      screen.getByText('LOGIN').closest('a')?.getAttribute('href')
    ).toBe('/login')
  })
})
