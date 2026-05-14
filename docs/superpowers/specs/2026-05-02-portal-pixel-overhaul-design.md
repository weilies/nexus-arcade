# Portal Pixel Overhaul — Design Spec

**Date:** 2026-05-02
**Status:** Approved
**Scope:** Full visual overhaul of Nexus Arcade portal (Next.js 14 + Tailwind + Supabase)

## Summary

Replace current dark CRT/retro-arcade theme with a cute 2D pixel art aesthetic inspired by Terraria + Stardew Valley. All screens get full-width pixel art backgrounds (generated via Leonardo.ai). UI switches to rounded cards, Pixelify Sans font, emoji icons, bottom tab navigation.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Color Palette | Warm Meadows (Stardew-inspired) | Golden wheat, soft greens, warm browns, pastel skies, sky blue. Cozy and inviting. |
| Character Style | Chibi Pixel (Stardew-like) | Big heads, tiny bodies, 16-32px sprites. Cute and readable. |
| Font | Pixelify Sans (Google Fonts) | SIL OFL license (free). Pixel aesthetic but far more readable than Press Start 2P. |
| UI Style | Rounded cards, big text, emoji icons | 12-16px border radius on cards/buttons. 16px+ body text. 48px min touch targets. |
| Navigation | Bottom tab bar (mobile-first) | Fixed bottom nav with emoji + label. Desktop: same tabs as top bar or sidebar. |
| Background Art | Leonardo.ai generated | Full-width pixel art per screen behind semi-transparent content panels. |
| Auth | Email/password + Google + Discord SSO | Supabase supports email signup. All three methods on Sign In and Register screens. |

## Font Stack

| Role | Font | Size |
|------|------|------|
| Headings | Pixelify Sans (weight 600-700) | 18-24px |
| Labels / Nav | Pixelify Sans (weight 400-500) | 12-14px |
| Body / Forms | System font (Inter, Segoe UI) | 15-16px |
| Touch targets | — | Min 48px |

## Screens

### 1. Home (`/`)
- Full pixel art background: cute village scene, warm sunset, chibi NPCs
- Semi-transparent content panel (warm cream/beige, ~92% opacity)
- Hero: castle emoji + "NEXUS ARCADE" heading
- Featured game card (same as Games loop card, just one)
- "More Games" button links to `/games`
- Bottom nav active: HOME

### 2. Games (`/games`)
- Full pixel art background: arcade hall interior, colorful cabinets, chibi characters
- Content panel: "GAMES" heading
- Simple loop: fetch all `status = 'live'` games from Supabase `games` table
- Each game: rounded card with pixel icon/thumbnail, name, description, play arrow
- No pagination — single scrollable list
- Empty state: "Coming Soon" placeholder card (greyed out)
- Bottom nav active: GAMES

### 3. Contact (`/contact`)
- Full pixel art background: post office / mailbox scene
- Content panel: "CONTACT" heading
- Facebook button (link, external)
- Email button (mailto: link)
- Bottom nav active: CONTACT

### 4. Sign In (`/login`) — rename route to `/login`
- Full pixel art background: castle gate / treehouse entrance, chibi guard
- Content panel: "SIGN IN" heading, lock emoji
- Email + password fields (rounded inputs, icons)
- "SIGN IN" button (amber gradient)
- "— OR —" divider
- Google SSO button + Discord SSO button (side by side)
- "No account? Register here" link
- Bottom nav active: SIGN IN

### 5. Register (`/register`) — new route
- Full pixel art background: similar to sign in but brighter, open door
- Content panel: "REGISTER" heading, pencil emoji
- Username + Email + Password fields
- "CREATE ACCOUNT" button (green gradient)
- "— OR —" divider
- Google SSO button + Discord SSO button
- "Already have account? Sign in" link
- Bottom nav active: SIGN IN (same tab as login — these are siblings)

### 6. Game Play (`/games/[slug]`) — existing, minimal changes
- Keep iframe embed for Godot web export
- Update top bar to use Pixelify Sans + Warm Meadows colors
- Full-screen background can be solid or gradient (no art needed — game takes focus)

### 7. Leaderboard (`/leaderboard/[slug]`) — existing stub
- Apply new theme, keep stub content
- Full implementation out of scope for this overhaul

## Color Palette (Tailwind Config)

```js
colors: {
  meadow: {
    sky: '#87CEEB',
    grass: '#82c45d',
    wheat: '#f4d03f',
    earth: '#8B5E3C',
    dark: '#5a3a1f',
    cream: '#FFF8EB',
    pink: '#f7d4d4',
  },
  amber: {
    light: '#e8a040',
    DEFAULT: '#c07a20',
    dark: '#8B5E3C',
  },
  ui: {
    card: '#FFFFFF',
    panel: 'rgba(255,248,235,0.92)',
    muted: '#aaa',
    border: '#e0d5c0',
  }
}
```

## Component Changes

### Nav → BottomTabBar (new)
- Remove current `<Nav />` top bar
- New `BottomTabBar` component: fixed to bottom, 4 tabs (Home, Games, Contact, Sign In)
- Each tab: emoji icon + Pixelify Sans label
- Active tab: full color + gold label. Inactive: 50% opacity
- Desktop: same tabs rendered as centered top bar (simpler, matches current layout pattern)
- Hidden on game play screen (fullscreen game focus)

### GameCard → GameCard (revised)
- Rounded corners (16px), white background, amber border
- Larger thumbnail area (64x64px icon)
- Pixelify Sans title, system font description
- "PLAY NOW" or "▶" arrow

### New: AuthCard
- Shared component for Sign In + Register
- Rounded white card, emoji header, form fields, SSO buttons
- Props: `mode: 'signin' | 'register'`

### New: ContactCard
- Simple card with FB + Email action buttons
- Each button: icon + label, rounded, gradient background

### GameFrame — minimal changes
- Update title bar colors and font
- Everything else stays the same

## Supabase

- `games` table already exists with `slug`, `name`, `status`, `launched_at`
- Email auth: enable in Supabase dashboard (Authentication → Providers → Email)
- No schema migrations needed for this overhaul

## Background Art — Leonardo.ai Prompts

Each screen needs a full-width pixel art background. Generate at 1536×2048 (portrait, mobile-first) or 2048×1536 (landscape, desktop). Cover both orientations with CSS `background-size: cover`.

| Screen | Prompt |
|--------|--------|
| Home | "Cute pixel art village scene, Stardew Valley style with Terraria detail level. Warm golden sunset lighting. Chibi NPCs with big heads waving. Green meadows, wheat fields, wooden houses with thatched roofs. Cozy inviting atmosphere. 16-bit pixel art game background. Pastel sky with soft clouds." |
| Games | "Cute pixel art arcade hall interior, Stardew Valley style. Colorful game cabinets lining the walls. Chibi characters with big heads playing games. Warm indoor lighting from hanging lanterns. Wooden floorboards. Cozy nostalgic atmosphere. 16-bit pixel art game background." |
| Contact | "Cute pixel art post office scene, Stardew Valley style. Warm afternoon sunlight. Wooden mailbox with letters. Chibi postal worker character waving. Flowers and trees around a cozy cottage. Inviting peaceful atmosphere. 16-bit pixel art game background." |
| Sign In | "Cute pixel art castle gate or treehouse entrance, Stardew Valley style. Chibi guard character with friendly smile. Warm welcoming lighting. Open gate inviting entrance. Vines and flowers on stone walls. Magical cozy atmosphere. 16-bit pixel art game background." |
| Register | "Cute pixel art open doorway scene, Stardew Valley style. Brighter more colorful than castle gate. New adventurer arriving. Sparkles and welcoming banners. Open green meadow beyond the door. Exciting fresh start atmosphere. 16-bit pixel art game background." |

## Manual Steps Required

1. **Leonardo.ai**: Generate 5 background images using prompts above. Save to `portal/public/bg/`
2. **Supabase Dashboard**: Enable Email auth provider (Authentication → Providers → Email)
3. **Google Fonts**: No manual step — loaded via CSS @import in layout
4. **Facebook URL + Email**: User to provide actual FB profile URL and contact email for Contact page

## Route Changes

| Old | New | Notes |
|-----|-----|-------|
| `/` | `/` | Home — rewritten |
| `/login` | `/login` | Sign In — rewritten, add email/password |
| `/games/[slug]` | `/games/[slug]` | Game play — minimal style update |
| `/leaderboard/[slug]` | `/leaderboard/[slug]` | Stub — theme update only |
| `/seasons` | — | Removed (stub, unused) |
| `/profile/[username]` | — | Removed (stub, unused) |
| — | `/games` | New — game listing page |
| — | `/contact` | New — FB + email contact |
| — | `/register` | New — email signup form |

## Out of Scope

- Leaderboard full implementation
- Season system
- User profiles
- Game upload/admin UI
- Online multiplayer changes
- Auth callback changes (existing callback route works for both email + SSO)
