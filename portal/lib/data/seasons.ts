import { createClient } from '@/lib/supabase/server'

export interface Season {
  id: string
  name: string
  starts_at: string
  ends_at: string
  prize_label: string
  game_id: string
}

export async function getActiveSeason(gameSlug: string): Promise<Season | null> {
  const supabase = createClient()
  const now = new Date().toISOString()

  const { data: game } = await supabase
    .from('games')
    .select('id')
    .eq('slug', gameSlug)
    .single()

  if (!game) return null

  const { data } = await supabase
    .from('seasons')
    .select('*')
    .eq('game_id', game.id)
    .lte('starts_at', now)
    .gte('ends_at', now)
    .single()

  return data
}
