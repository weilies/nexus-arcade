import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { LeaderboardWidget } from '../LeaderboardWidget'

const mockScores = [
  { rank: 1, username: 'WeiTat', score: 2830, user_id: 'u1' },
  { rank: 2, username: 'Kira', score: 2440, user_id: 'u2' },
  { rank: 3, username: 'xXnoob', score: 1920, user_id: 'u3' },
]

describe('LeaderboardWidget', () => {
  it('renders heading', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={mockScores} />)
    expect(screen.getByText('🏆 TOP PLAYERS')).toBeDefined()
  })

  it('renders first place player', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={mockScores} />)
    expect(screen.getByText('#1 WeiTat')).toBeDefined()
  })

  it('renders score formatted with commas', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={mockScores} />)
    expect(screen.getByText('2,830')).toBeDefined()
  })

  it('shows empty state when no scores', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={[]} />)
    expect(screen.getByText('NO SCORES YET')).toBeDefined()
  })

  it('view full link goes to game leaderboard', () => {
    render(<LeaderboardWidget gameSlug="ultimate-ttt" scores={[]} />)
    expect(
      screen.getByText('VIEW FULL ►').closest('a')?.getAttribute('href')
    ).toBe('/leaderboard/ultimate-ttt')
  })
})
