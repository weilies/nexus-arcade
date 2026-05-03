'use client'

import { useState, useEffect, useCallback } from 'react'
import { getAllGames, createGame, updateGame, deleteGame } from '@/lib/data/games-admin'
import type { Game } from '@/lib/data/games'

const STATUS_OPTIONS = [
  { value: 'coming_soon', label: 'COMING SOON' },
  { value: 'live', label: 'LIVE' },
  { value: 'retired', label: 'RETIRED' },
] as const

const EMPTY_FORM: { slug: string; name: string; description: string; thumbnail_url: string; status: Game['status'] } = { slug: '', name: '', description: '', thumbnail_url: '', status: 'coming_soon' }

export function AdminDashboard() {
  const [games, setGames] = useState<Game[]>([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(EMPTY_FORM)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const loadGames = useCallback(async () => {
    const data = await getAllGames()
    setGames(data)
    setLoading(false)
  }, [])

  useEffect(() => { loadGames() }, [loadGames])

  function handleEdit(game: Game) {
    setEditingId(game.id)
    setForm({
      slug: game.slug,
      name: game.name,
      description: game.description || '',
      thumbnail_url: game.thumbnail_url || '',
      status: game.status,
    })
    setError('')
  }

  function handleCancel() {
    setEditingId(null)
    setForm(EMPTY_FORM)
    setError('')
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setSaving(true)
    setError('')

    if (editingId) {
      const { error: err } = await updateGame(editingId, {
        slug: form.slug,
        name: form.name,
        description: form.description || null,
        thumbnail_url: form.thumbnail_url || null,
        status: form.status,
      })
      if (err) { setError(err.message); setSaving(false); return }
    } else {
      const { error: err } = await createGame({
        slug: form.slug,
        name: form.name,
        description: form.description || undefined,
        thumbnail_url: form.thumbnail_url || undefined,
        status: form.status,
      })
      if (err) { setError(err.message); setSaving(false); return }
    }

    setForm(EMPTY_FORM)
    setEditingId(null)
    setSaving(false)
    await loadGames()
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this game?')) return
    const { error: err } = await deleteGame(id)
    if (err) { setError(err.message); return }
    await loadGames()
  }

  function setField(field: string, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }))
  }

  return (
    <div className="min-h-screen px-4 py-6 bg-retro-glow">
      <div className="w-full max-w-3xl mx-auto">
        <div className="flex items-center justify-between mb-6">
          <h1 className="font-pixel text-2xl font-bold text-[#e8e8f0]">
            ADMIN <span style={{ color: 'var(--neon-magenta)' }}>CMS</span>
          </h1>
          <a href="/" className="font-pixel text-xs" style={{ color: 'var(--neon-cyan)' }}>
            ← BACK
          </a>
        </div>

        {/* Add / Edit Form */}
        <div className="card-panel mb-6">
          <h2 className="font-pixel text-lg font-semibold text-[#e8e8f0] mb-4">
            {editingId ? 'EDIT GAME' : 'ADD GAME'}
          </h2>
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <input
                className="input-field"
                placeholder="Slug (e.g. tictactoe)"
                value={form.slug}
                onChange={(e) => setField('slug', e.target.value)}
                required
              />
              <input
                className="input-field"
                placeholder="Name"
                value={form.name}
                onChange={(e) => setField('name', e.target.value)}
                required
              />
            </div>
            <input
              className="input-field"
              placeholder="Description"
              value={form.description}
              onChange={(e) => setField('description', e.target.value)}
            />
            <input
              className="input-field"
              placeholder="Thumbnail URL (optional)"
              value={form.thumbnail_url}
              onChange={(e) => setField('thumbnail_url', e.target.value)}
            />
            <div className="flex items-center gap-3">
              <select
                className="input-field w-auto"
                value={form.status}
                onChange={(e) => setField('status', e.target.value)}
              >
                {STATUS_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
              <button type="submit" disabled={saving} className="btn-primary flex-1">
                {saving ? 'SAVING...' : editingId ? 'UPDATE' : 'CREATE'}
              </button>
              {editingId && (
                <button type="button" onClick={handleCancel} className="btn-secondary">
                  CANCEL
                </button>
              )}
            </div>
            {error && (
              <div className="text-sm font-pixel p-2 rounded-lg" style={{ background: 'rgba(255,45,149,0.15)', color: 'var(--neon-magenta)' }}>
                {error}
              </div>
            )}
          </form>
        </div>

        {/* Game List */}
        <div className="card-panel">
          <h2 className="font-pixel text-lg font-semibold text-[#e8e8f0] mb-4">
            ALL GAMES ({games.length})
          </h2>
          {loading ? (
            <div className="font-pixel text-sm text-[#8888aa]">Loading...</div>
          ) : games.length === 0 ? (
            <div className="font-pixel text-sm text-[#666688]">No games yet.</div>
          ) : (
            <div className="flex flex-col gap-3">
              {games.map((game) => (
                <div key={game.id}
                     className="flex items-center gap-4 bg-[#12122a] rounded-xl p-4 border border-[#2a2a4a]">
                  <div className="w-12 h-12 rounded-2xl flex items-center justify-center text-2xl flex-shrink-0"
                       style={{ background: 'rgba(0,229,255,0.1)' }}>
                    {game.thumbnail_url ? <img src={game.thumbnail_url} alt="" className="w-full h-full object-cover rounded-2xl" /> : '🎮'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-pixel text-lg font-semibold text-[#e8e8f0] truncate">{game.name}</div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <code className="text-xs text-[#666688]">{game.slug}</code>
                      <span className="text-xs font-pixel px-2 py-0.5 rounded-full"
                            style={{
                              background: game.status === 'live' ? 'rgba(0,255,136,0.15)' : game.status === 'retired' ? 'rgba(255,45,149,0.15)' : 'rgba(255,215,0,0.15)',
                              color: game.status === 'live' ? 'var(--neon-green)' : game.status === 'retired' ? 'var(--neon-magenta)' : 'var(--neon-gold)',
                            }}>
                        {game.status.toUpperCase()}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={() => handleEdit(game)}
                            className="font-pixel text-xs px-3 py-2 rounded-lg border-none cursor-pointer min-h-[40px]"
                            style={{ background: 'rgba(0,229,255,0.15)', color: 'var(--neon-cyan)' }}>
                      EDIT
                    </button>
                    <button onClick={() => handleDelete(game.id)}
                            className="font-pixel text-xs px-3 py-2 rounded-lg border-none cursor-pointer min-h-[40px]"
                            style={{ background: 'rgba(255,45,149,0.15)', color: 'var(--neon-magenta)' }}>
                      DEL
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
