import Link from 'next/link'

interface GameCardProps {
  slug: string
  name: string
  description?: string | null
  thumbnailUrl?: string | null
  accentColor?: string
  stageNum?: number
  compact?: boolean
}

export function GameCard({
  slug,
  name,
  description,
  thumbnailUrl,
  accentColor = '#00e5ff',
  stageNum = 1,
  compact = false,
}: GameCardProps) {
  if (compact) {
    return (
      <Link
        href={`/games/${slug}`}
        className="flex items-center gap-4 bg-[#1a1a2e] rounded-xl p-4 border border-[#2a2a4a] shadow-lg hover:border-[#3a3a66] hover:shadow-[0_0_16px_rgba(0,229,255,0.1)] transition-all"
      >
        <div
          className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
          style={{ background: 'rgba(0,229,255,0.1)' }}
        >
          {thumbnailUrl ? (
            <img src={thumbnailUrl} alt={name} className="w-full h-full object-cover rounded-2xl" />
          ) : (
            '🎮'
          )}
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-pixel text-xl font-semibold text-[#e8e8f0] truncate">{name}</div>
          {description && (
            <div className="text-sm text-[#8888aa] mt-0.5 truncate">{description}</div>
          )}
        </div>
      </Link>
    )
  }

  const stageLabel = String(stageNum).padStart(2, '0')
  const cardGlow = accentColor + '55'

  return (
    <Link href={`/games/${slug}`} className="block game-card" style={{ '--card-glow': cardGlow } as React.CSSProperties}>
      {/* Outer shell: sharp corners, colored top stripe */}
      <div
        style={{
          borderTop: `3px solid ${accentColor}`,
          borderRight: `1px solid ${accentColor}30`,
          borderBottom: `1px solid ${accentColor}30`,
          borderLeft: `1px solid ${accentColor}30`,
          borderRadius: '2px',
          overflow: 'hidden',
          background: '#07071a',
        }}
      >
        {/* Stage header */}
        <div
          style={{
            padding: '5px 12px',
            background: `${accentColor}12`,
            borderBottom: `1px solid ${accentColor}25`,
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <span
            style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '10px',
              fontWeight: '700',
              color: accentColor,
              letterSpacing: '0.18em',
              textTransform: 'uppercase',
            }}
          >
            STAGE {stageLabel}
          </span>
          <span style={{ fontSize: '8px', color: `${accentColor}50`, letterSpacing: '3px' }}>
            ■ ■ ■
          </span>
        </div>

        {/* CRT Screen */}
        <div style={{ position: 'relative', aspectRatio: '2/1', background: '#000', overflow: 'hidden' }}>
          {thumbnailUrl ? (
            <img
              src={thumbnailUrl}
              alt={name}
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
            />
          ) : (
            <div
              style={{
                width: '100%',
                height: '100%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: `radial-gradient(ellipse at 50% 40%, ${accentColor}18 0%, #000 70%)`,
                fontSize: '48px',
                filter: `drop-shadow(0 0 12px ${accentColor}88)`,
              }}
            >
              🎮
            </div>
          )}
          {/* Scanlines */}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              pointerEvents: 'none',
              zIndex: 2,
              background:
                'repeating-linear-gradient(to bottom, transparent 0px, transparent 3px, rgba(0,0,0,0.22) 3px, rgba(0,0,0,0.22) 4px)',
            }}
          />
          {/* CRT vignette */}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              pointerEvents: 'none',
              zIndex: 3,
              background:
                'radial-gradient(ellipse at 50% 50%, transparent 50%, rgba(0,0,0,0.62) 100%)',
            }}
          />
        </div>

        {/* Control panel */}
        <div style={{ padding: '10px 14px 13px', background: '#07071a' }}>
          <div
            style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '13px',
              fontWeight: '700',
              color: '#e8e8f0',
              textShadow: `0 0 10px ${accentColor}70`,
              letterSpacing: '0.05em',
              textTransform: 'uppercase',
              marginBottom: description ? '5px' : '10px',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            {name}
          </div>
          {description && (
            <div
              style={{
                fontSize: '11px',
                color: '#55556a',
                lineHeight: '1.5',
                marginBottom: '10px',
                overflow: 'hidden',
                display: '-webkit-box',
                WebkitLineClamp: 2,
                WebkitBoxOrient: 'vertical',
              } as React.CSSProperties}
            >
              {description}
            </div>
          )}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              paddingTop: '8px',
              borderTop: `1px solid ${accentColor}20`,
            }}
          >
            <span
              className="blink-insert"
              style={{
                fontFamily: 'Orbitron, sans-serif',
                fontSize: '10px',
                fontWeight: '700',
                color: accentColor,
                letterSpacing: '0.14em',
              }}
            >
              ▶ INSERT COIN
            </span>
            <div
              style={{
                flex: 1,
                height: '1px',
                background: `linear-gradient(to right, ${accentColor}40, transparent)`,
              }}
            />
          </div>
        </div>
      </div>
    </Link>
  )
}
