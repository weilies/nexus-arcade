'use client'

import { useState, useCallback } from 'react'
import { getAllGames, createGame, updateGame, deleteGame } from '@/lib/data/games-admin'
import type { Game } from '@/lib/data/games'

const STATUS_OPTIONS = [
  { value: 'coming_soon', label: 'COMING SOON' },
  { value: 'live', label: 'LIVE' },
  { value: 'retired', label: 'RETIRED' },
] as const

const STATUS_COLOR: Record<Game['status'], string> = {
  live: '#00ff88',
  coming_soon: '#ffd700',
  retired: '#ff2d95',
}

const EMPTY_FORM: { slug: string; name: string; description: string; thumbnail_url: string; status: Game['status'] } = {
  slug: '',
  name: '',
  description: '',
  thumbnail_url: '',
  status: 'coming_soon',
}

interface AdminDashboardProps {
  initialGames: Game[]
  initialError: string | null
}

const panelStyle = (accentColor = '#ff2d95'): React.CSSProperties => ({
  borderTop: `3px solid ${accentColor}`,
  borderRight: `1px solid ${accentColor}28`,
  borderBottom: `1px solid ${accentColor}28`,
  borderLeft: `1px solid ${accentColor}28`,
  borderRadius: '2px',
  overflow: 'hidden',
  background: '#07071a',
  marginBottom: '20px',
})

const panelHeaderStyle = (accentColor = '#ff2d95'): React.CSSProperties => ({
  padding: '6px 14px',
  background: accentColor + '12',
  borderBottom: `1px solid ${accentColor}22`,
  display: 'flex',
  alignItems: 'center',
  gap: '8px',
})

const panelTitleStyle = (accentColor = '#ff2d95'): React.CSSProperties => ({
  fontFamily: 'Orbitron, sans-serif',
  fontSize: '10px',
  fontWeight: '700',
  color: accentColor,
  letterSpacing: '0.2em',
  flex: 1,
})

const inputStyle: React.CSSProperties = {
  borderRadius: '2px',
  background: '#04040f',
  borderColor: '#1e1e3a',
}

const fieldLabelStyle: React.CSSProperties = {
  fontFamily: 'Orbitron, sans-serif',
  fontSize: '9px',
  fontWeight: '700',
  color: '#333366',
  letterSpacing: '0.18em',
  marginBottom: '5px',
}

export function AdminDashboard({ initialGames, initialError }: AdminDashboardProps) {
  const [games, setGames] = useState<Game[]>(initialGames)
  const [loading, setLoading] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(initialError ?? '')

  const loadGames = useCallback(async () => {
    setLoading(true)
    try {
      const data = await getAllGames()
      setGames(data)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load games')
    } finally {
      setLoading(false)
    }
  }, [])

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

  const formAccent = editingId ? '#ffd700' : '#ff2d95'

  return (
    <div className="min-h-screen bg-retro-glow bg-retro-grid px-4 py-8 pb-24 md:pb-8">
      <div className="w-full max-w-4xl mx-auto">

        {/* Page header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '28px' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <span style={{
                display: 'inline-block',
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                background: '#00ff88',
                boxShadow: '0 0 8px #00ff88',
              }} className="blink-star" />
              <h1 style={{
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '22px',
                fontWeight: '900',
                color: '#e8e8f0',
                letterSpacing: '0.1em',
              }}>
                ADMIN <span style={{ color: '#ff2d95', textShadow: '0 0 12px rgba(255,45,149,0.5)' }}>CMS</span>
              </h1>
            </div>
            <div style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '9px',
              color: '#333355',
              letterSpacing: '0.22em',
              marginTop: '4px',
            }}>
              GAME MANAGEMENT TERMINAL
            </div>
          </div>
          <a
            href="/"
            style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '10px',
              color: '#00e5ff',
              textDecoration: 'none',
              letterSpacing: '0.15em',
              padding: '8px 14px',
              border: '1px solid rgba(0,229,255,0.25)',
              borderRadius: '2px',
              background: 'rgba(0,229,255,0.06)',
            }}
          >
            ← EXIT
          </a>
        </div>

        {/* Add / Edit Form */}
        <div style={panelStyle(formAccent)}>
          <div style={panelHeaderStyle(formAccent)}>
            <span style={{ fontSize: '8px', color: formAccent + '55', letterSpacing: '3px' }}>■ ■</span>
            <span style={panelTitleStyle(formAccent)}>
              {editingId ? 'EDIT GAME ENTRY' : 'ADD GAME ENTRY'}
            </span>
            <span style={{ fontSize: '8px', color: formAccent + '55', letterSpacing: '3px' }}>■ ■</span>
          </div>
          <div style={{ padding: '20px' }}>
            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <div style={fieldLabelStyle}>SLUG</div>
                  <input
                    className="input-field"
                    style={inputStyle}
                    placeholder="e.g. tictactoe"
                    value={form.slug}
                    onChange={(e) => setField('slug', e.target.value)}
                    required
                  />
                </div>
                <div>
                  <div style={fieldLabelStyle}>NAME</div>
                  <input
                    className="input-field"
                    style={inputStyle}
                    placeholder="Game Name"
                    value={form.name}
                    onChange={(e) => setField('name', e.target.value)}
                    required
                  />
                </div>
              </div>
              <div>
                <div style={fieldLabelStyle}>DESCRIPTION</div>
                <input
                  className="input-field"
                  style={inputStyle}
                  placeholder="Short description"
                  value={form.description}
                  onChange={(e) => setField('description', e.target.value)}
                />
              </div>
              <div>
                <div style={fieldLabelStyle}>THUMBNAIL URL</div>
                <input
                  className="input-field"
                  style={inputStyle}
                  placeholder="https://... (optional)"
                  value={form.thumbnail_url}
                  onChange={(e) => setField('thumbnail_url', e.target.value)}
                />
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: '10px' }}>
                <div style={{ flexShrink: 0 }}>
                  <div style={fieldLabelStyle}>STATUS</div>
                  <select
                    className="input-field"
                    style={{ ...inputStyle, width: 'auto', paddingRight: '32px' }}
                    value={form.status}
                    onChange={(e) => setField('status', e.target.value)}
                  >
                    {STATUS_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>{opt.label}</option>
                    ))}
                  </select>
                </div>
                <button type="submit" disabled={saving} className="btn-primary flex-1" style={{ borderRadius: '2px', flex: 1 }}>
                  {saving ? 'SAVING...' : editingId ? 'UPDATE' : 'CREATE'}
                </button>
                {editingId && (
                  <button type="button" onClick={handleCancel} className="btn-secondary" style={{ borderRadius: '2px', whiteSpace: 'nowrap' }}>
                    CANCEL
                  </button>
                )}
              </div>
              {error && (
                <div style={{
                  background: 'rgba(255,45,149,0.08)',
                  border: '1px solid rgba(255,45,149,0.3)',
                  borderRadius: '2px',
                  padding: '10px 12px',
                  fontFamily: 'Orbitron, sans-serif',
                  fontSize: '10px',
                  color: '#ff6b9d',
                  letterSpacing: '0.05em',
                }}>
                  ERR: {error}
                </div>
              )}
            </form>
          </div>
        </div>

        {/* Game List */}
        <div style={panelStyle('#00e5ff')}>
          <div style={panelHeaderStyle('#00e5ff')}>
            <span style={{ fontSize: '8px', color: '#00e5ff55', letterSpacing: '3px' }}>■ ■</span>
            <span style={panelTitleStyle('#00e5ff')}>
              ALL GAMES
            </span>
            <span style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '10px',
              fontWeight: '700',
              color: '#00e5ff66',
              letterSpacing: '0.12em',
            }}>
              {games.length} ENTRIES
            </span>
          </div>
          <div style={{ padding: '16px' }}>
            {loading ? (
              <div style={{ fontFamily: 'Orbitron, sans-serif', fontSize: '11px', color: '#333355', letterSpacing: '0.15em', padding: '12px 0' }}>
                LOADING...
              </div>
            ) : games.length === 0 ? (
              <div style={{ fontFamily: 'Orbitron, sans-serif', fontSize: '11px', color: '#222244', letterSpacing: '0.15em', padding: '12px 0' }}>
                NO ENTRIES FOUND
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {games.map((game) => {
                  const statusColor = STATUS_COLOR[game.status]
                  return (
                    <div
                      key={game.id}
                      className="admin-game-row"
                      style={{ borderLeftColor: statusColor }}
                    >
                      {/* Thumbnail */}
                      <div
                        style={{
                          width: '44px',
                          height: '44px',
                          borderRadius: '2px',
                          flexShrink: 0,
                          overflow: 'hidden',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          background: statusColor + '12',
                          fontSize: '20px',
                        }}
                      >
                        {game.thumbnail_url ? (
                          <img src={game.thumbnail_url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                        ) : (
                          '🎮'
                        )}
                      </div>

                      {/* Info */}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{
                          fontFamily: 'Orbitron, sans-serif',
                          fontSize: '13px',
                          fontWeight: '700',
                          color: '#e8e8f0',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                          textShadow: `0 0 8px ${statusColor}44`,
                        }}>
                          {game.name}
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '3px' }}>
                          <code style={{ fontSize: '11px', color: '#333355', fontFamily: 'monospace' }}>{game.slug}</code>
                          <span style={{
                            fontFamily: 'Orbitron, sans-serif',
                            fontSize: '9px',
                            fontWeight: '700',
                            color: statusColor,
                            letterSpacing: '0.12em',
                            padding: '2px 6px',
                            border: `1px solid ${statusColor}40`,
                            borderRadius: '1px',
                            background: statusColor + '14',
                          }}>
                            {game.status.toUpperCase().replace('_', ' ')}
                          </span>
                        </div>
                      </div>

                      {/* Actions */}
                      <div style={{ display: 'flex', gap: '6px', flexShrink: 0 }}>
                        <button
                          onClick={() => handleEdit(game)}
                          style={{
                            fontFamily: 'Orbitron, sans-serif',
                            fontSize: '10px',
                            fontWeight: '700',
                            padding: '8px 12px',
                            background: 'rgba(0,229,255,0.08)',
                            border: '1px solid rgba(0,229,255,0.25)',
                            borderRadius: '2px',
                            color: '#00e5ff',
                            cursor: 'pointer',
                            letterSpacing: '0.1em',
                            minHeight: '36px',
                          }}
                        >
                          EDIT
                        </button>
                        <button
                          onClick={() => handleDelete(game.id)}
                          style={{
                            fontFamily: 'Orbitron, sans-serif',
                            fontSize: '10px',
                            fontWeight: '700',
                            padding: '8px 12px',
                            background: 'rgba(255,45,149,0.08)',
                            border: '1px solid rgba(255,45,149,0.25)',
                            borderRadius: '2px',
                            color: '#ff2d95',
                            cursor: 'pointer',
                            letterSpacing: '0.1em',
                            minHeight: '36px',
                          }}
                        >
                          DEL
                        </button>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </div>

      </div>
    </div>
  )
}
