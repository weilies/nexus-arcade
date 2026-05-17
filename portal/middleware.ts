import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  // Serve pre-gzipped Godot exports when client supports gzip.
  // Static `public/` files can't auto-negotiate Content-Encoding, so we
  // rewrite the URL to the .gz sibling and headers (set in next.config.js)
  // tell the browser to decompress transparently.
  const url = request.nextUrl
  const accepts = request.headers.get('accept-encoding') || ''
  if (accepts.includes('gzip')) {
    const m = url.pathname.match(/^(\/games\/[^/]+\/index\.(wasm|pck))$/)
    if (m) {
      const gzUrl = url.clone()
      gzUrl.pathname = m[1] + '.gz'
      const res = NextResponse.rewrite(gzUrl)
      res.headers.set('Content-Encoding', 'gzip')
      res.headers.set('Vary', 'Accept-Encoding')
      res.headers.set('Cache-Control', 'public, max-age=31536000, immutable')
      res.headers.set(
        'Content-Type',
        m[2] === 'wasm' ? 'application/wasm' : 'application/octet-stream'
      )
      return res
    }
  }

  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          )
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  await supabase.auth.getUser()
  return supabaseResponse
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
