import { NextRequest, NextResponse } from 'next/server'
import { readFile } from 'fs/promises'
import path from 'path'

export async function GET(
  request: NextRequest,
  { params }: { params: { slug: string } }
) {
  const dir = path.join(process.cwd(), 'public', 'games', params.slug)
  const accepts = request.headers.get('accept-encoding') || ''
  const base = {
    'Content-Type': 'application/wasm',
    'Cache-Control': 'public, max-age=31536000, immutable',
    'Vary': 'Accept-Encoding',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
  }

  if (accepts.includes('gzip')) {
    try {
      const gz = await readFile(path.join(dir, 'index.wasm.gz'))
      return new NextResponse(gz, {
        headers: { ...base, 'Content-Encoding': 'gzip' },
      })
    } catch {
      // .gz not found — fall through to raw
    }
  }

  try {
    const raw = await readFile(path.join(dir, 'index.wasm'))
    return new NextResponse(raw, { headers: base })
  } catch {
    return new NextResponse('Not found', { status: 404 })
  }
}
