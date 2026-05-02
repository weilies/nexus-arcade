import { createClient } from '@/lib/supabase/server'

export interface Game {
  id: string
  slug: string
  name: string
  status: 'coming_soon' | 'live' | 'retired'
  launched_at: string | null
}

export async function getGameBySlug(slug: string): Promise<Game | null> {
  const supabase = createClient()
  const { data } = await supabase
    .from('games')
    .select('*')
    .eq('slug', slug)
    .single()
  return data
}

export async function getFeaturedGame(): Promise<Game | null> {
  const supabase = createClient()
  const { data } = await supabase
    .from('games')
    .select('*')
    .eq('status', 'live')
    .order('launched_at', { ascending: true })
    .limit(1)
    .single()
  return data
}

export async function getAllLiveGames(): Promise<Game[]> {
  const supabase = createClient()
  const { data } = await supabase
    .from('games')
    .select('*')
    .eq('status', 'live')
    .order('launched_at', { ascending: true })
  return data ?? []
}
