import { isPlatformAdmin } from '@/lib/data/admin'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { ScoringDashboard } from './ScoringDashboard'

export default async function AdminScoringPage() {
  const isAdmin = await isPlatformAdmin()
  if (!isAdmin) redirect('/login')

  const supabase = createClient()
  const [starsRes, tiersRes, gamesRes] = await Promise.all([
    supabase.from('game_mode_stars').select('*, games(name)').order('game_id'),
    supabase.from('point_tiers').select('*, games(name)').order('min_streak'),
    supabase.from('games').select('id, name, slug').order('name'),
  ])

  return (
    <ScoringDashboard
      initialStars={starsRes.data ?? []}
      initialTiers={tiersRes.data ?? []}
      games={gamesRes.data ?? []}
    />
  )
}
