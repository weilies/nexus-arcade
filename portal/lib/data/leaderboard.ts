import { createClient } from '@/lib/supabase/server'

export interface LeaderboardEntry {
  rank: number
  username: string
  score: number
  user_id: string
}

export async function getTopScores(
  gameSlug: string,
  limit = 5
): Promise<LeaderboardEntry[]> {
  const supabase = createClient()

  const { data: game } = await supabase
    .from('games')
    .select('id')
    .eq('slug', gameSlug)
    .single()

  if (!game) return []

  const { data } = await supabase
    .from('scores')
    .select('score, user_id, users!inner(username)')
    .eq('game_id', game.id)
    .order('score', { ascending: false })
    .limit(limit)

  return (data ?? []).map((row: any, i) => ({
    rank: i + 1,
    username: row.users.username,
    score: row.score,
    user_id: row.user_id,
  }))
}
