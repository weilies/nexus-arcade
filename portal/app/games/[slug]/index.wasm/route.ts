import { NextRequest, NextResponse } from 'next/server'
import { readFile } from 'fs/promises'
import path from 'path'

// Serves index.wasm with cache headers.
// Compression handled client-side: index.html fetch-interceptor fetches
// index.wasm.gz directly and decompresses via DecompressionStream.
export async function GET(
  _request: NextRequest,
  { params }: { params: { slug: string } }
) {
  const dir = path.join(process.cwd(), 'public', 'games', params.slug)
  try {
    const raw = await readFile(path.join(dir, 'index.wasm'))
    return new NextResponse(raw, {
      headers: {
        'Content-Type': 'application/wasm',
        'Cache-Control': 'public, max-age=31536000, immutable',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
      },
    })
  } catch {
    return new NextResponse('Not found', { status: 404 })
  }
}
