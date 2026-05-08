# #HashAttack! Main Menu Overhaul — Design Spec

> **Status:** approved
> **Date:** 2026-05-08
> **Agents:** Uma (UI/Artist), Gladys (Game Designer)

**Goal:** Overhaul MainMenu.tscn with Win8 Metro-style flat square tiles, swipe-select game mode carousel with visual board previews, timer toggle, and randomized first-turn notification.

## 1. Layout Architecture

```
┌──────────────────────────────────┐  y=0
│  [#HashAttack!]          [→]    │  header (72px)
├──────────────────────────────────┤  y=72
│                                  │
│    ← [  Board Preview  ] →       │  carousel (480px)
│       Classic Mode               │  mode name + dots ● ○ ○
│                                  │
├──────────────────────────────────┤  y=552
│                                  │
│  ┌──────┐ ┌──────┐ ┌──────┐     │
│  │  🤖   │ │  👥   │ │  🌐   │     │  tile bar (250px)
│  │  1P   │ │  2P   │ │Online │     │
│  └──────┘ └──────┘ └──────┘     │
│       ┌──────┐                    │
│       │  🏆   │                    │
│       │Leader│                    │
│       └──────┘                    │
├──────────────────────────────────┤  y=802
│         ★ profile info           │  footer (158px)
└──────────────────────────────────┘  y=960
```

- **Header:** Title left-aligned, sign-in icon top-right
- **Carousel:** Center-anchored, swipe/drag + arrow buttons, board preview 70% opacity, dot indicators
- **Tile Bar:** Square tiles (160×160), flat backgrounds, SVG icon centered, small text label bottom-left
- **Footer:** Profile info when signed in

## 2. Visual Mode Differentiation

| Mode | Board Preview | Spin | Flavor |
|------|--------------|------|--------|
| Classic | 3×3 grid, X/O placed, cyan win line | Slow Y-axis rotation (30° swing) | Clean, familiar |
| Ultimate | 3×3 grid of mini 3×3 boards, one board highlighted | Slow X-axis tilt + slight Z twist | Complex, layered |
| Ephemerate | 3×3 grid with faded X/O (varying opacity) | Fade pulse cycle (opacity breathes 40%-70%) | Ghostly, tense |

- Board previews at 70% opacity against `#0a0a1a` background
- NeonGlow.gdshader adds subtle cyan glow to active cells
- 2D skew illusion via `rotation_degrees` + `scale` tweens (no 3D renderer, GL Compatibility mode)

## 3. Tile Bar Design

| Property | Value |
|----------|-------|
| Tile size | 160×160 px |
| Background | `#0e0e2a` flat |
| Border | 2px `#a855f7`, sharp corners |
| Hover border | 2px `#00d4ff` with NeonGlow |
| Icon size | 64px SVG centered |
| Label | Orbitron 14pt, `#94a3b8`, bottom-left |
| Separation | 12px gap |
| Hover scale | Tween 1.0 → 1.05, 0.12s ease |

Icon mapping: Robot SVG (1P), Users SVG (2P), Globe SVG (Online), Trophy FA6 (Leaderboard).

### Carousel Controls
- Swipe: mouse drag left/right gesture detection in GDScript
- Arrow buttons: `←` `→` flanking board preview, FA6 icons
- Dot indicators: below mode name, `● ○ ○` format, cyan for active

## 4. Game Modes

### Classic
Standard 3×3 tic-tac-toe. AI plays as O (minimax on hard, random on easy). Player always X by default, but first turn randomized.

### Ultimate
Ultimate Tic Tac Toe: 9 small 3×3 boards arranged in a 3×3 meta-grid. A move's cell position forces the opponent to play in the corresponding small board. Win a small board → claim that square in the meta-board. Win meta-board → win game. Full/claimed boards are skipped.

### Ephemerate
Marks fade 25% per opponent move and vanish after the 4th placement. e.g. P1 places O → after P2's X, O is at 75% opacity → after P1's next O, first O is at 50% → after P2's X, first O at 25% → after P1's next O, first O vanishes completely. Players can reuse vacated cells. High memory + strategy tension.

## 5. Timer Toggle

- Shown next to mode name in carousel area
- `fa-clock` icon at 18pt, cyan when on, dim grey when off
- Label "10s" below when active
- **Default:** OFF
- **Disabled for:** 2P Local (greyed out, always off)
- **Storage:** `Globals.use_timer: bool`, `Globals.timer_seconds = 10`
- GameBoard checks `Globals.use_timer` before starting TurnTimer

## 6. Randomized First Turn

- In VS_AI mode: randomly pick X or O for player
- If player is O, AI moves first
- Show overlay label: "YOU GO FIRST" or "OPPONENT GOES FIRST"
- Fade out after 3 seconds via tween (modulate:a 1.0 → 0.0)

## 7. Supabase — Mode Stars

- `game_mode_stars` table: add rows for `classic`, `ultimate`, `ephemerate` under `#HashAttack!` game
- Each mode tracked independently for streak/scoring

## 8. Files

| File | Action | Purpose |
|------|--------|---------|
| `MainMenu.tscn` | Rewrite | New node tree with carousel + tile bar |
| `MainMenu.gd` | Rewrite | Carousel logic, timer toggle, random turn announce |
| `GameBoard.gd` | Modify | 10s timer option, random first-turn, turn announce |
| `Globals.gd` | Modify | Add `use_timer`, `timer_seconds` |
| `GameState.gd` | Modify | Ultimate mode board logic (meta-board) |
| `ModeCarousel.gd` | Create | Reusable carousel: swipe, arrows, dots |
| `ModeTile.gd` | Create | Single tile button component |
| `TurnAnnounce.gd` | Create | "YOU GO FIRST" / "OPPONENT GOES FIRST" overlay |
| `EphemerateTracker.gd` | Create | Fade tracking for Ephemerate mode marks |
| `ModePreview.gd` | Create | Renders board preview for carousel |
| `LeaderboardScene.tscn` | No change | Already built, referenced from tile |
| `test_scoring.gd` | Modify | Add tests for new modes |

## 9. Style Compliance

- Godot colors: `#00d4ff` (cyan), `#a855f7` (purple), `#ff2d95` (magenta)
- Background: `#0a0a1a`
- Font: Orbitron via `res://fonts/Orbitron.ttf`
- Icons: SVG for buttons, FA6 autoload for labels
- No emojis in UI text — use FA6.icon() for all icon labels
