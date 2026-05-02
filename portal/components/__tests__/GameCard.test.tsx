import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { GameCard } from '../GameCard'

describe('GameCard', () => {
  it('renders game name', () => {
    render(<GameCard slug="test-game" name="Test Game" />)
    expect(screen.getByText('Test Game')).toBeDefined()
  })

  it('renders play button linking to game page', () => {
    render(<GameCard slug="test-game" name="Test Game" />)
    const link = screen.getByText('▶ PLAY NOW').closest('a')
    expect(link?.getAttribute('href')).toBe('/games/test-game')
  })

  it('renders compact variant without play button', () => {
    render(<GameCard slug="test-game" name="Test Game" compact />)
    expect(screen.queryByText('▶ PLAY NOW')).toBeNull()
    const link = screen.getByText('Test Game').closest('a')
    expect(link?.getAttribute('href')).toBe('/games/test-game')
  })
})
