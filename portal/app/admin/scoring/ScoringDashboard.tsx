'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/browser'

interface Game    { id: string; name: string; slug: string }
interface StarRow { game_id: string; game_mode: string; base_stars: number; games?: { name: string } }
interface TierRow { id: string; game_id: string | null; game_mode: string | null; min_streak: number; max_streak: number | null; multiplier: number; games?: { name: string } }

interface Props {
  initialStars: StarRow[]
  initialTiers: TierRow[]
  games: Game[]
}

export function ScoringDashboard({ initialStars, initialTiers, games }: Props) {
  const [stars, setStars]   = useState<StarRow[]>(initialStars)
  const [tiers, setTiers]   = useState<TierRow[]>(initialTiers)
  const [status, setStatus] = useState('')
  const supabase = createClient()

  async function saveStars(row: StarRow, n: number) {
    setStatus('Saving...')
    await supabase.from('game_mode_stars')
      .upsert({ game_id: row.game_id, game_mode: row.game_mode, base_stars: n })
    setStars(p => p.map(r =>
      r.game_id === row.game_id && r.game_mode === row.game_mode ? { ...r, base_stars: n } : r))
    setStatus('Saved.')
  }

  async function addStars(gameId: string, mode: string, n: number) {
    setStatus('Adding...')
    const { data } = await supabase.from('game_mode_stars')
      .upsert({ game_id: gameId, game_mode: mode, base_stars: n })
      .select('*, games(name)').single()
    if (data) setStars(p => [...p, data as StarRow])
    setStatus('Added.')
  }

  async function deleteTier(id: string) {
    setStatus('Deleting...')
    await supabase.from('point_tiers').delete().eq('id', id)
    setTiers(p => p.filter(t => t.id !== id))
    setStatus('Deleted.')
  }

  async function addTier(gameId: string | null, mode: string | null, min: number, max: number | null, mult: number) {
    setStatus('Adding...')
    const { data } = await supabase.from('point_tiers')
      .insert({ game_id: gameId, game_mode: mode, min_streak: min, max_streak: max, multiplier: mult })
      .select('*, games(name)').single()
    if (data) setTiers(p => [...p, data as TierRow])
    setStatus('Added.')
  }

  const inputCls = "bg-transparent border rounded px-2 py-1 text-sm"
  const inputStyle = { borderColor: 'var(--border-dim)' }
  const btnPrimary = { background: 'var(--neon-cyan)', color: '#000' }
  const btnDanger  = { background: 'var(--neon-magenta)', color: '#000' }

  return (
    <div className="p-6 min-h-screen" style={{ background: 'var(--bg-deep)', color: 'var(--text-primary)' }}>
      <h1 className="font-pixel text-2xl mb-2" style={{ color: 'var(--neon-cyan)' }}>SCORING CONFIG</h1>
      {status && <p className="text-sm mb-4" style={{ color: 'var(--neon-cyan)' }}>{status}</p>}

      {/* Mode Stars */}
      <section className="mb-10">
        <h2 className="font-pixel text-base mb-3">MODE STARS</h2>
        <table className="w-full text-sm mb-4">
          <thead><tr style={{ color: 'var(--text-muted)' }}>
            <th className="text-left p-2">Game</th><th className="text-left p-2">Mode</th>
            <th className="text-left p-2">Stars</th><th className="text-left p-2" />
          </tr></thead>
          <tbody>
            {stars.map(row => {
              const [val, setVal] = useState(row.base_stars)  // eslint-disable-line
              return (
                <tr key={`${row.game_id}-${row.game_mode}`} className="border-b" style={{ borderColor: 'var(--border-dim)' }}>
                  <td className="p-2">{row.games?.name ?? row.game_id}</td>
                  <td className="p-2">{row.game_mode}</td>
                  <td className="p-2">
                    <input type="number" min={1} value={val}
                      onChange={e => setVal(Number(e.target.value))}
                      className={`w-16 ${inputCls}`} style={inputStyle} />
                  </td>
                  <td className="p-2">
                    <button onClick={() => saveStars(row, val)}
                      className="text-xs px-2 py-1 rounded" style={btnPrimary}>Save</button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        <AddStarsForm games={games} onAdd={addStars} />
      </section>

      {/* Tiers */}
      <section>
        <h2 className="font-pixel text-base mb-2">STREAK MULTIPLIER TIERS</h2>
        {tiers.length === 0 && (
          <div className="mb-4 p-3 border rounded text-sm"
               style={{ borderColor: 'var(--neon-magenta)', color: 'var(--neon-magenta)' }}>
            ⚠ No tiers configured — wins award 0 points until tiers are added.
          </div>
        )}
        <table className="w-full text-sm mb-4">
          <thead><tr style={{ color: 'var(--text-muted)' }}>
            <th className="text-left p-2">Game</th><th className="text-left p-2">Mode</th>
            <th className="text-left p-2">Min</th><th className="text-left p-2">Max</th>
            <th className="text-left p-2">Mult</th><th className="text-left p-2" />
          </tr></thead>
          <tbody>
            {tiers.map(t => (
              <tr key={t.id} className="border-b" style={{ borderColor: 'var(--border-dim)' }}>
                <td className="p-2">{t.games?.name ?? 'All'}</td>
                <td className="p-2">{t.game_mode ?? 'All'}</td>
                <td className="p-2">{t.min_streak}</td>
                <td className="p-2">{t.max_streak ?? '∞'}</td>
                <td className="p-2">{t.multiplier}×</td>
                <td className="p-2">
                  <button onClick={() => deleteTier(t.id)}
                    className="text-xs px-2 py-1 rounded" style={btnDanger}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <AddTierForm games={games} onAdd={addTier} />
      </section>
    </div>
  )
}

function AddStarsForm({ games, onAdd }: { games: Game[]; onAdd: (g: string, m: string, n: number) => void }) {
  const [gameId, setGameId] = useState(games[0]?.id ?? '')
  const [mode,   setMode]   = useState('classic')
  const [stars,  setStars]  = useState(1)
  const cls = "bg-transparent border rounded px-2 py-1 text-sm"
  const sty = { borderColor: 'var(--border-dim)' }
  return (
    <div className="flex gap-2 flex-wrap items-center">
      <select value={gameId} onChange={e => setGameId(e.target.value)} className={cls} style={sty}>
        {games.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
      </select>
      <input value={mode} onChange={e => setMode(e.target.value)} placeholder="mode"
        className={`w-28 ${cls}`} style={sty} />
      <input type="number" min={1} value={stars} onChange={e => setStars(Number(e.target.value))}
        className={`w-16 ${cls}`} style={sty} />
      <button onClick={() => onAdd(gameId, mode, stars)}
        className="text-sm px-3 py-1 rounded" style={{ background: 'var(--neon-cyan)', color: '#000' }}>
        + Add
      </button>
    </div>
  )
}

function AddTierForm({ games, onAdd }: { games: Game[]; onAdd: (g: string|null, m: string|null, min: number, max: number|null, mult: number) => void }) {
  const [gameId, setGameId] = useState('')
  const [mode,   setMode]   = useState('')
  const [min,    setMin]    = useState(1)
  const [max,    setMax]    = useState('')
  const [mult,   setMult]   = useState(1)
  const cls = "bg-transparent border rounded px-2 py-1 text-sm"
  const sty = { borderColor: 'var(--border-dim)' }
  return (
    <div className="flex gap-2 flex-wrap items-center">
      <select value={gameId} onChange={e => setGameId(e.target.value)} className={cls} style={sty}>
        <option value="">All games</option>
        {games.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
      </select>
      <input value={mode} onChange={e => setMode(e.target.value)} placeholder="mode (blank=all)"
        className={`w-32 ${cls}`} style={sty} />
      <input type="number" min={1} value={min} onChange={e => setMin(Number(e.target.value))} placeholder="min"
        className={`w-16 ${cls}`} style={sty} />
      <input type="number" value={max} onChange={e => setMax(e.target.value)} placeholder="max"
        className={`w-20 ${cls}`} style={sty} />
      <input type="number" step="0.01" min={0.01} value={mult} onChange={e => setMult(Number(e.target.value))}
        className={`w-16 ${cls}`} style={sty} />
      <button onClick={() => onAdd(gameId||null, mode||null, min, max?Number(max):null, mult)}
        className="text-sm px-3 py-1 rounded" style={{ background: 'var(--neon-cyan)', color: '#000' }}>
        + Add Tier
      </button>
    </div>
  )
}
