import { Nav } from '@/components/Nav'

export default function SeasonsPage() {
  return (
    <div className="min-h-screen bg-arcade-bg">
      <Nav />
      <div className="max-w-2xl mx-auto px-4 py-8 font-mono">
        <h1 className="text-arcade-gold text-xl tracking-widest mb-4">SEASONS</h1>
        <p className="text-arcade-dim text-sm">Seasonal events — coming in Plan 3.</p>
      </div>
    </div>
  )
}
