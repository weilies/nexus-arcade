# Nexus Arcade — Style Guide

> **Purpose:** Single source of truth for all visual, animation, and sound values.
> All agents (game-dev, ui-artist, marketer, tester) reference this doc.
> GM resolves ambiguity here — never in code.

---

## 1. Color Palette

Two contexts, intentionally split. Game (Godot) values use display-optimized tones.
Portal (CSS) values use slightly different tones for readability against dark UI surfaces.

### 1.1 Game Colors (Godot GDScript)

| Role | Hex | GDScript | Notes |
|------|-----|----------|-------|
| Background | `#0a0a1a` | `Color("#0a0a1a")` | Near-black, all scenes |
| Cell bg | `#1a1a2e` | `Color("#1a1a2e")` | Grid cell fill |
| Panel bg | `#12122a` | `Color("#12122a")` | Cards, panels, overlays |
| X mark | `#00d4ff` | `Color("#00d4ff")` | Cooler blue-cyan |
| O mark | `#a855f7` | `Color("#a855f7")` | Neon purple |
| Accent | `#ff2d95` | `Color("#ff2d95")` | Hot magenta, 80s arcade pop |
| Gold | `#ffd700` | `Color("#ffd700")` | Stars, achievements, rewards |
| Green | `#00ff88` | `Color("#00ff88")` | Success, ready states |
| Text primary | `#e8e8f0` | `Color("#e8e8f0")` | Body text, labels |
| Text secondary | `#aaaacc` | `Color("#aaaacc")` | Subtitles, less important |
| Text muted | `#666688` | `Color("#666688")` | Placeholder, disabled |

### 1.2 Portal Colors (CSS Custom Properties)

| Variable | Value | Usage |
|----------|-------|-------|
| `--bg-deep` | `#0a0a1a` | Page background |
| `--bg-panel` | `#12122a` | Panel/card fill |
| `--bg-card` | `#1a1a2e` | Card surface |
| `--border-dim` | `#2a2a4a` | Default borders |
| `--border-glow` | `#3a3a66` | Hover/focus borders |
| `--neon-cyan` | `#00e5ff` | Primary CTA, links, focus ring (brighter tone than game X for UI readability) |
| `--neon-magenta` | `#ff2d95` | Secondary CTA, accents |
| `--neon-purple` | `#b366ff` | Tertiary accents, Discord hover (warmer tone than game O) |
| `--neon-gold` | `#ffd700` | Badges, achievements |
| `--neon-green` | `#00ff88` | Success states |
| `--text-primary` | `#e8e8f0` | Body text |
| `--text-secondary` | `#aaaacc` | Subtitles |
| `--text-muted` | `#666688` | Placeholder |

### 1.3 Intentional Split Rationale

| Context | X / Cyan | O / Purple | Why |
|---------|----------|------------|-----|
| Godot game | `#00d4ff` | `#a855f7` | Display-optimized, cooler, lower luminance for dark game scenes |
| Portal CSS | `#00e5ff` | `#b366ff` | Brighter for readability against dark UI, WCAG contrast compliance |

Both contexts share the same background, panel, and text values.

---

## 2. Typography

### 2.1 Portal (Web)

| Role | Font | Weight | Size |
|------|------|--------|------|
| Headings, nav, buttons | `Orbitron` (via Google Fonts) | 700 / 900 | Responsive |
| Body text | `system-ui, -apple-system, sans-serif` | 400 | 15–17px |
| Monospace (code) | `ui-monospace, monospace` | 400 | 14px |

`font-pixel` Tailwind alias → `Orbitron`.

### 2.2 Godot (Game)

- **ArcadeTheme.tres** — to be populated with Godot default font + neon-tinted Theme values
- All game UI uses Control nodes with `add_theme_*_override()` for per-instance styling
- Marks (X/O) use `Label` nodes with `font_color` override — no custom font file needed

---

## 3. Animation Values

### 3.1 Godot Tweens

| Animation | Tween | Duration | Easing | Details |
|-----------|-------|----------|--------|---------|
| Piece placement | scale `0 → 1.1 → 1.0` | 0.12s + 0.06s | `TRANS_BACK EASE_OUT` | Overshoot then settle |
| Cell hover | scale `1.0 → 1.05 → 1.0` | 0.1s | `TRANS_QUAD` | Subtle lift |
| Win line pulse | modulate `1.3 → 1.0 → 1.3` | 0.4s per phase | default | Looping, applied per cell |
| Turn timer warning | scale `1.0 → 1.15 → 1.0` | 0.5s cycle | default | Starts at ≤5s remaining |
| AI thinking | `". "` animated dots | 0.5s per dot | — | `randf_range(1.0, 3.0)` delay before move |

### 3.2 Portal Transitions

| Element | Property | Duration | Easing |
|---------|----------|----------|--------|
| Button hover | `box-shadow` | 0.2s | default |
| Button press | `translateY(2px)` | instant | — |
| Card hover | `scale(1.025) translateY(-2px)` | 0.18s | `ease` |
| Input focus | `border-color`, `box-shadow` | 0.2s | default |
| OAuth button hover | `border-color`, `color`, `background` | 0.2s | default |

### 3.3 Portal Blink Keyframes

| Name | Cycle | Pattern | Usage |
|------|-------|---------|-------|
| `blink-arcade` | 0.8s step-start | 50% on, 50% off | General blink |
| `blink-star` | 1.5s step-start | 50% on, 50% off | Stars, decor (randomize delay per element) |
| `blink-insert` | 2.5s step-start | 75% on, 25% off | "INSERT COIN" text |

---

## 4. Shaders

### 4.1 NeonGlow (Godot canvas_item shader)

Location: `games/tic-tac-toe/shaders/NeonGlow.gdshader`

| Uniform | Default | Usage |
|---------|---------|-------|
| `glow_color` | `(0.0, 0.831, 1.0, 1.0)` (~ `#00d4ff`) | Tint color |
| `glow_strength` | `2.0` | Standard glow |
| `glow_strength` (win) | `3.5` | Win state emphasis |

Apply via `ShaderMaterial` on `ColorRect` or `TextureRect` nodes (e.g. grid border).

---

## 5. Sound Design

> Placeholder — populated when audio assets are produced.

| Sound | Context | Priority |
|-------|---------|----------|
| Cell place click | Any piece placement | v1 |
| Win fanfare | Match won | v1 |
| Draw tone | Match draw | v1 |
| Turn timer tick | ≤5s remaining | v1 |
| UI hover / select | Button interaction | v2 |
| Background music | Lo-fi synthwave loop | v2 |

---

## 6. Godot Project Conventions

| Concern | Convention |
|---------|------------|
| Renderer | GL Compatibility (mobile web target) |
| Viewport | 720×960, stretch mode `canvas_items` |
| Tweens | `create_tween()` (not deprecated `$Tween` node) |
| FontAwesome | FA6 autoload for label icons; SVG `Texture2D` for button icons |
| Autoloads | `Globals`, `SFX`, `FA6` |
| Emoji | Never use emoji in Button/Label text — use SVG icons (buttons) or FA6 (labels) |

---

## 7. Portal (Next.js) Conventions

| Concern | Convention |
|---------|------------|
| Framework | Next.js 14 App Router |
| Styling | Tailwind CSS 3.4 |
| Auth | Supabase SSR (Google OAuth) |
| Game frames | iframe with postMessage bridge |
| Deployment | Railway (portal + Godot static exports) |
| Godot exports | `portal/public/games/<slug>/` |

---

## 8. Style Evolution Process

1. GM spots discrepancy or wants change
2. GM asks plain-language question (no hex codes, no technical terms)
3. Agents research via NotebookLM KB + codebase audit
4. GM gives direction in plain language
5. Style guide updated first
6. Agents propagate to code

**The style guide is the source of truth. Code follows the guide, not the other way around.**

---

## Changelog

| Date | Author | Summary |
|------|--------|---------|
| 2026-05-05 | GM resolution | Initial guide — resolved 5 color discrepancies, documented intentional portal/game split |
