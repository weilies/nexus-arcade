# Portal — Homepage Image, Auth UX, Font Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Swap Pixelify Sans → Orbitron across the portal, add arcade cabinet image to homepage, and show explicit SIGN OUT label in the nav.

**Architecture:** Three independent changes — CSS/config font swap, page layout update, component label fix. No new routes or DB changes needed (admin SQL already applied).

**Tech Stack:** Next.js 14, Tailwind CSS, Vitest + Testing Library, Supabase Auth

---

## File Map

| File | Change |
|------|--------|
| `portal/app/globals.css` | Swap Google Fonts import; update hardcoded `font-family` in `.btn-primary` / `.btn-secondary` |
| `portal/tailwind.config.ts` | Change `font-pixel` alias from `Pixelify Sans` → `Orbitron` |
| `portal/app/page.tsx` | Two-column layout; render arcade cabinet image |
| `portal/public/images/arcade-cabinet.png` | New image asset (manual save step) |
| `portal/components/BottomTabBar.tsx` | Replace username text with `SIGN OUT` in two places |
| `portal/components/__tests__/BottomTabBar.test.tsx` | Add signed-in state test verifying `SIGN OUT` label |

---

## Task 1: Font Overhaul — globals.css + tailwind.config

No automated test (CSS font-family not testable in jsdom).

**Files:**
- Modify: `portal/app/globals.css`
- Modify: `portal/tailwind.config.ts`

- [ ] **Step 1: Update Google Fonts import in globals.css**

Replace line 1 of `portal/app/globals.css`:

```css
@import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&display=swap');
```

- [ ] **Step 2: Update hardcoded font-family in .btn-primary and .btn-secondary**

In `portal/app/globals.css`, find `.btn-primary` (around line 59) and `.btn-secondary` (around line 86). Change both `font-family` declarations:

```css
/* .btn-primary */
font-family: 'Orbitron', sans-serif;

/* .btn-secondary */
font-family: 'Orbitron', sans-serif;
```

- [ ] **Step 3: Update tailwind font-pixel alias**

In `portal/tailwind.config.ts`, change the `fontFamily` extension:

```ts
fontFamily: {
  pixel: ['"Orbitron"', 'sans-serif'],
},
```

- [ ] **Step 4: Commit**

```bash
git add portal/app/globals.css portal/tailwind.config.ts
git commit -m "feat: swap Pixelify Sans → Orbitron for improved readability"
```

---

## Task 2: Sign-Out Button Label

**Files:**
- Modify: `portal/components/BottomTabBar.tsx`
- Modify: `portal/components/__tests__/BottomTabBar.test.tsx`

- [ ] **Step 1: Write the failing test**

In `portal/components/__tests__/BottomTabBar.test.tsx`, add `waitFor` to imports and add a configurable `mockUser` variable. Replace the file contents with:

```tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { BottomTabBar } from '../BottomTabBar'

let mockUser: { id: string; email: string; user_metadata: Record<string, string> } | null = null

vi.mock('next/navigation', () => ({
  usePathname: () => '/',
  useRouter: () => ({ push: vi.fn(), refresh: vi.fn() }),
}))

vi.mock('@/lib/supabase/browser', () => ({
  createClient: () => ({
    auth: {
      getUser: () => Promise.resolve({ data: { user: mockUser } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: vi.fn() } } }),
    },
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            maybeSingle: () => Promise.resolve({ data: null }),
          }),
        }),
      }),
    }),
  }),
}))

describe('BottomTabBar', () => {
  it('renders nav tabs and sign in when logged out', () => {
    mockUser = null
    render(<BottomTabBar />)
    expect(screen.getAllByText('HOME')).toHaveLength(2)
    expect(screen.getAllByText('GAMES')).toHaveLength(2)
    expect(screen.getAllByText('SIGN IN')).toHaveLength(2)
  })

  it('hides when current path is in hideOn', () => {
    const { container } = render(<BottomTabBar hideOn={['/']} />)
    expect(container.firstChild).toBeNull()
  })

  it('does not show admin link for non-admin users', () => {
    mockUser = null
    render(<BottomTabBar />)
    expect(screen.queryByText('ADMIN')).toBeNull()
  })

  it('shows SIGN OUT when user is signed in', async () => {
    mockUser = { id: '123', email: 'test@example.com', user_metadata: { full_name: 'Test User' } }
    render(<BottomTabBar />)
    await waitFor(() => {
      expect(screen.getAllByText('SIGN OUT')).toHaveLength(2)
    })
    mockUser = null
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd portal && npx vitest run components/__tests__/BottomTabBar.test.tsx
```

Expected: FAIL — `Unable to find an element with the text: SIGN OUT`

- [ ] **Step 3: Update BottomTabBar — desktop nav sign-out button**

In `portal/components/BottomTabBar.tsx`, find the desktop nav signed-in button (around line 226). Replace:

```tsx
<button
  onClick={handleSignOut}
  className="flex items-center gap-2 px-4 py-2 min-h-[48px] bg-transparent border-none cursor-pointer"
>
  <span className="font-pixel text-sm font-semibold" style={{ color: '#8888aa' }}>
    {authLabel.toUpperCase()}
  </span>
</button>
```

With:

```tsx
<button
  onClick={handleSignOut}
  className="flex items-center gap-2 px-4 py-2 min-h-[48px] bg-transparent border-none cursor-pointer"
>
  <span className="font-pixel text-sm font-semibold" style={{ color: '#8888aa' }}>
    SIGN OUT
  </span>
</button>
```

- [ ] **Step 4: Update BottomTabBar — mobile header sign-out button**

In `portal/components/BottomTabBar.tsx`, find the mobile header signed-in button (around line 119). Replace:

```tsx
<button
  onClick={handleSignOut}
  className="font-pixel text-xs font-semibold bg-transparent border-none cursor-pointer min-h-[48px] px-2"
  style={{ color: '#8888aa' }}
>
  {authLabel.toUpperCase().slice(0, 8)}
</button>
```

With:

```tsx
<button
  onClick={handleSignOut}
  className="font-pixel text-xs font-semibold bg-transparent border-none cursor-pointer min-h-[48px] px-2"
  style={{ color: '#8888aa' }}
>
  SIGN OUT
</button>
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd portal && npx vitest run components/__tests__/BottomTabBar.test.tsx
```

Expected: PASS — all 4 tests green

- [ ] **Step 6: Commit**

```bash
git add portal/components/BottomTabBar.tsx portal/components/__tests__/BottomTabBar.test.tsx
git commit -m "feat: show explicit SIGN OUT label in nav (desktop + mobile)"
```

---

## Task 3: Homepage Arcade Cabinet Image

**Files:**
- Create: `portal/public/images/arcade-cabinet.png`
- Modify: `portal/app/page.tsx`

- [ ] **Step 1: Save the image asset**

Save the arcade cabinet pixel art image (provided in the original user conversation) to:

```
portal/public/images/arcade-cabinet.png
```

_(If running as a subagent without conversation image context: ask the user to manually drag the image into `portal/public/images/` and name it `arcade-cabinet.png`.)_

- [ ] **Step 2: Update homepage to two-column layout**

Replace the entire contents of `portal/app/page.tsx` with:

```tsx
import Image from 'next/image'

export default function HomePage() {
  return (
    <div className="flex-1 flex items-center justify-center px-4 py-6 bg-retro-glow">
      <div className="flex flex-col md:flex-row items-center justify-center gap-8 w-full max-w-3xl">

        {/* Left: text card */}
        <div className="card-panel w-full max-w-sm text-center">
          {/* Title row */}
          <div className="flex items-center justify-center gap-3 mb-3">
            <span className="text-5xl" style={{ textShadow: '0 0 20px rgba(255,45,149,0.6)' }}>👾</span>
            <h1 className="font-pixel text-2xl font-bold text-[#e8e8f0]">
              NEXUS <span style={{ color: 'var(--neon-cyan)' }}>ARCADE</span>
            </h1>
          </div>

          {/* Pantun */}
          <div className="space-y-2 mb-5">
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span style={{ color: 'var(--neon-cyan)' }}>▸</span> Neon nights ignite pixel fights.
            </p>
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span style={{ color: 'var(--neon-magenta)' }}>▸</span> Coins drop loud in arcade halls.
            </p>
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span style={{ color: 'var(--neon-purple)' }}>▸</span> Conquer rounds under neon lights.
            </p>
            <p className="font-pixel text-sm text-[#aaaacc]">
              <span style={{ color: 'var(--neon-gold)' }}>▸</span> Legends echo through these walls.
            </p>
          </div>

          {/* Blink */}
          <div
            className="font-pixel text-sm blink-arcade"
            style={{ color: 'var(--neon-gold)', textShadow: '0 0 10px rgba(255,215,0,0.7)' }}
          >
            -INSERT COIN-
          </div>
        </div>

        {/* Right: arcade cabinet image */}
        <div className="flex-shrink-0 flex items-center justify-center">
          <Image
            src="/images/arcade-cabinet.png"
            alt="Nexus Arcade cabinet"
            width={320}
            height={480}
            className="object-contain max-h-[480px] w-auto"
            style={{ filter: 'drop-shadow(0 0 24px rgba(0,229,255,0.35))' }}
            priority
          />
        </div>

      </div>
    </div>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add portal/public/images/arcade-cabinet.png portal/app/page.tsx
git commit -m "feat: add arcade cabinet image to homepage, two-column desktop layout"
```

---

## Task 4: Visual Verification

- [ ] **Step 1: Start dev server**

```bash
cd portal && npm run dev
```

Open `http://localhost:3000` in browser.

- [ ] **Step 2: Check font**

Verify: nav labels, button text, headings all render in Orbitron (geometric, readable). No Pixelify Sans remaining.

- [ ] **Step 3: Check homepage layout**

- Desktop (≥768px): text card left, arcade cabinet image right, neon cyan glow around image
- Mobile (<768px): text card on top, image below, centered

- [ ] **Step 4: Check sign-out**

Sign in → verify nav shows "SIGN OUT" (not username). Click "SIGN OUT" → redirects to `/`, user signed out.

- [ ] **Step 5: Check admin access**

Sign in as `weilies.chok@gmail.com` → hamburger menu / desktop nav shows "ADMIN" link → `/admin` loads AdminDashboard (not redirect to login).

- [ ] **Step 6: Run full test suite**

```bash
cd portal && npx vitest run
```

Expected: all tests pass.
