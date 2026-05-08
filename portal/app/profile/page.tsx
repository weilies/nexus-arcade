import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function ProfilePage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login?return_to=/profile')

  const [pointsRes, streaksRes, txRes] = await Promise.all([
    supabase.from('member_points').select('total_points').eq('user_id', user.id).single(),
    supabase.from('consecutive_wins')
      .select('game_id, game_mode, best_streak, games(name)')
      .eq('user_id', user.id),
    supabase.from('point_transactions')
      .select('id, game_mode, source, amount, created_at, games(name)')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(10),
  ])

  const totalPoints = pointsRes.data?.total_points ?? 0
  const streaks     = streaksRes.data ?? []
  const transactions = txRes.data ?? []

  return (
    <div className="min-h-screen p-6" style={{ background: 'var(--bg-deep)', color: 'var(--text-primary)' }}>
      <h1 className="font-pixel text-3xl mb-8" style={{ color: 'var(--neon-cyan)' }}>PROFILE</h1>

      <section className="mb-8 p-4 rounded-lg border" style={{ borderColor: 'var(--border-dim)', background: 'var(--bg-card)' }}>
        <p className="text-xs mb-1" style={{ color: 'var(--text-muted)' }}>TOTAL STARS</p>
        <p className="font-pixel text-4xl" style={{ color: 'var(--neon-cyan)' }}>★ {totalPoints}</p>
      </section>

      {streaks.length > 0 && (
        <section className="mb-8">
          <h2 className="font-pixel text-sm mb-3" style={{ color: 'var(--text-secondary)' }}>BEST STREAKS</h2>
          <div className="grid gap-2">
            {(streaks as any[]).map((s) => (
              <div key={`${s.game_id}-${s.game_mode}`}
                   className="flex justify-between p-3 rounded border"
                   style={{ borderColor: 'var(--border-dim)', background: 'var(--bg-card)' }}>
                <span className="text-sm font-semibold">
                  {s.games?.name ?? '—'} · {(s.game_mode as string).toUpperCase()}
                </span>
                <span style={{ color: 'var(--neon-cyan)' }}>🔥 {s.best_streak}</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {transactions.length > 0 && (
        <section>
          <h2 className="font-pixel text-sm mb-3" style={{ color: 'var(--text-secondary)' }}>RECENT AWARDS</h2>
          <div className="grid gap-2">
            {(transactions as any[]).map((t) => (
              <div key={t.id}
                   className="flex justify-between items-center p-3 rounded border"
                   style={{ borderColor: 'var(--border-dim)', background: 'var(--bg-card)' }}>
                <div>
                  <span className="text-sm font-semibold">{t.games?.name ?? '—'}</span>
                  <span className="text-xs ml-2" style={{ color: 'var(--text-muted)' }}>
                    {t.game_mode} · {(t.source as string).replace('_', ' ')}
                  </span>
                </div>
                <span className="font-pixel text-sm" style={{ color: 'var(--neon-cyan)' }}>+{t.amount} ★</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {streaks.length === 0 && transactions.length === 0 && (
        <p style={{ color: 'var(--text-muted)' }}>No activity yet. Win a match to earn your first stars!</p>
      )}
    </div>
  )
}
