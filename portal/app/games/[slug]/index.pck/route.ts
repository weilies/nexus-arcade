import { NextRequest, NextResponse } from 'next/server'
import { readFile } from 'fs/promises'
import path from 'path'

export async function GET(
  _request: NextRequest,
  { params }: { params: { slug: string } }
) {
  const dir = path.join(process.cwd(), 'public', 'games', params.slug)
  try {
    const raw = await readFile(path.join(dir, 'index.pck'))
    return new NextResponse(raw, {
      headers: {
        'Content-Type': 'application/octet-stream',
        'Cache-Control': 'public, max-age=31536000, immutable',
        'Cross-Origin-Resource-Policy': 'same-site',
      },
    })
  } catch {
    return new NextResponse('Not found', { status: 404 })
  }
}
