import { isPlatformAdmin } from '@/lib/data/admin'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { AdminDashboard } from './AdminDashboard'
import type { Game } from '@/lib/data/games'

export default async function AdminPage() {
  const isAdmin = await isPlatformAdmin()
  if (!isAdmin) redirect('/login')

  const supabase = createClient()
  const { data, error } = await supabase
    .from('games')
    .select('*')
    .order('launched_at', { ascending: true })

  return <AdminDashboard initialGames={(data ?? []) as Game[]} initialError={error?.message ?? null} />
}
