# Portal — Project-Specific Instructions

**Framework:** Next.js 14 App Router
**Styling:** Tailwind CSS 3.4
**Auth:** Supabase SSR (Google OAuth)
**Deployment:** Railway (portal + Godot static exports)

## Mandatory References

| Resource | Location |
|----------|----------|
| Style guide (portal colors) | `docs/style/nexus-arcade-style-guide.md` section 1.2 |
| Root CLAUDE.md | `CLAUDE.md` |

## Key Directories

```
portal/
  app/           — Next.js App Router pages + layouts
  components/    — React components (BottomTabBar, GameCard, GameFrame, etc.)
  lib/           — utilities, Supabase client
  public/
    games/       — Godot web exports (one subdir per slug)
  app/globals.css   — CSS custom properties + component styles
  tailwind.config.ts — Tailwind token palette
```

## Style Guide Compliance

- CSS custom properties in `globals.css` MUST match style guide section 1.2
- Tailwind config `colors` section must NOT contain meadow palette
- Portal uses intentionally different cyan/purple tones than Godot games:
  - Portal cyan: `#00e5ff` (brighter for UI readability)
  - Game cyan: `#00d4ff` (cooler for game display)
  - Portal purple: `#b366ff` (warmer tone)
  - Game purple: `#a855f7`
  - Do NOT "fix" one to match the other — this is intentional

## Neon Visual System (CSS)

| Class / Property | What it does |
|-----------------|--------------|
| `.btn-primary` | Neon cyan gradient CTA |
| `.btn-secondary` | Hot magenta gradient CTA |
| `.card-panel` | Dark glass card surface |
| `.input-field` | Dark input with neon cyan focus |
| `.bg-retro-grid` | Subtle cyan grid overlay |
| `.bg-retro-glow` | Cyan top + magenta bottom radial gradients |
| `.blink-arcade` (0.8s) | Fast blink for general use |
| `.blink-star` (1.5s) | Slower blink for stars/decor |
| `.blink-insert` (2.5s) | Slow blink, 75% duty cycle for "INSERT COIN" |
| `.game-card` | Hover: scale 1.025, -2px, 0.18s ease |
| `.oauth-btn` | Dark OAuth buttons with per-provider hover glow |

## Build & Run

```powershell
cd portal
npm run dev          # local dev server
npm run build        # production build
npm start            # production server
```

## Godot Export Integration

- Exports land in `portal/public/games/<slug>/`
- Embedded via `GameFrame.tsx` iframe component
- postMessage bridge for auth token handoff and match results

## Railway

Project: https://railway.com/project/74047641-eaad-4212-97c1-4bb84b416ac6

Deploy flow: push to GitHub → Railway auto-deploys from root `portal/` directory.
Healthcheck: GET `/api/health` — Next.js standalone server bound to `0.0.0.0`.
