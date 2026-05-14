import { createClient } from '@/lib/supabase/browser'
import type { Game } from './games'

export async function getAllGames(): Promise<Game[]> {
  const supabase = createClient()
  const { data, error } = await supabase
    .from('games')
    .select('*')
    .order('launched_at', { ascending: true })
  if (error) throw error
  return data ?? []
}

export async function createGame(game: {
  slug: string
  name: string
  description?: string | null
  thumbnail_url?: string | null
  status?: 'coming_soon' | 'live' | 'retired'
}) {
  const supabase = createClient()
  const { data, error } = await supabase
    .from('games')
    .insert({
      slug: game.slug,
      name: game.name,
      description: game.description || null,
      thumbnail_url: game.thumbnail_url || null,
      status: game.status || 'coming_soon',
    })
    .select()
    .single()
  return { data, error }
}

export async function updateGame(
  id: string,
  updates: {
    slug?: string
    name?: string
    description?: string | null
    thumbnail_url?: string | null
    status?: 'coming_soon' | 'live' | 'retired'
  }
) {
  const supabase = createClient()
  const { data, error } = await supabase
    .from('games')
    .update(updates)
    .eq('id', id)
    .select()
    .single()
  return { data, error }
}

export async function deleteGame(id: string) {
  const supabase = createClient()
  const { error } = await supabase
    .from('games')
    .delete()
    .eq('id', id)
  return { error }
}
