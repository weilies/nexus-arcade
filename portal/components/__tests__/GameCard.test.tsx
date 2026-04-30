import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { GameCard } from '../GameCard'

describe('GameCard', () => {
  it('renders game name uppercased', () => {
    render(<GameCard slug="ultimate-ttt" name="Ultimate Ttt" />)
    expect(screen.getByText('ULTIMATE TTT')).toBeDefined()
  })

  it('play now links to game page', () => {
    render(<GameCard slug="ultimate-ttt" name="Test Game" />)
    expect(
      screen.getByText('► PLAY NOW').closest('a')?.getAttribute('href')
    ).toBe('/games/ultimate-ttt')
  })

  it('shows placeholder when no thumbnail', () => {
    render(<GameCard slug="ultimate-ttt" name="Test" />)
    expect(screen.getByText('?')).toBeDefined()
  })

  it('renders thumbnail when provided', () => {
    render(
      <GameCard slug="ultimate-ttt" name="Test" thumbnailUrl="/thumb.png" />
    )
    expect(screen.getByRole('img').getAttribute('src')).toBe('/thumb.png')
  })
})
