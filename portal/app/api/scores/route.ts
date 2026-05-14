import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@/lib/supabase/server-admin'

export async function POST(req: NextRequest) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { slug, score, winner, mode } = await req.json()

  if (
    typeof score !== 'number' ||
    score < 0 ||
    score > 1_000_000 ||
    !['solo', 'local', 'online'].includes(mode) ||
    !['player', 'opponent', 'draw'].includes(winner)
  ) {
    return NextResponse.json({ error: 'Invalid score payload' }, { status: 400 })
  }

  const admin = createAdminClient()

  const { data: game } = await admin
    .from('games')
    .select('id')
    .eq('slug', slug)
    .single()

  if (!game) {
    return NextResponse.json({ error: 'Game not found' }, { status: 404 })
  }

  const { error } = await admin.from('scores').insert({
    user_id: user.id,
    game_id: game.id,
    score,
    mode,
  })

  if (error) {
    return NextResponse.json({ error: 'Failed to save score' }, { status: 500 })
  }

  return NextResponse.json({ ok: true })
}
