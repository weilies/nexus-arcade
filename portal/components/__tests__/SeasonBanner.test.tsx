import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { vi } from 'vitest'
import { SeasonBanner } from '../SeasonBanner'

describe('SeasonBanner', () => {
  beforeEach(() => {
    vi.setSystemTime(new Date('2026-04-30T00:00:00Z'))
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('renders season name uppercased', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-06-30T00:00:00Z" />)
    expect(screen.getByText(/Q2 2026/)).toBeDefined()
  })

  it('shows correct days remaining', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-05-02T00:00:00Z" />)
    expect(screen.getByText(/2 DAYS LEFT/)).toBeDefined()
  })

  it('shows singular DAY when 1 day left', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-05-01T00:00:00Z" />)
    expect(screen.getByText(/1 DAY LEFT/)).toBeDefined()
  })

  it('shows 0 days when season ended', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-01-01T00:00:00Z" />)
    expect(screen.getByText(/0 DAYS LEFT/)).toBeDefined()
  })

  it('renders join event button', () => {
    render(<SeasonBanner name="Q2 2026" endsAt="2026-06-30T00:00:00Z" />)
    expect(screen.getByText('JOIN EVENT')).toBeDefined()
  })
})
