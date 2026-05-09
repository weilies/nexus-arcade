# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Nexus Arcade

Game development project. Draws knowledge from NotebookLM KB for game design, engines, mechanics, and narrative inspiration.

## Commands

### Portal (Next.js)

```powershell
cd portal
npm run dev          # local dev server
npm run build        # production build
npm start            # production server
```

### Godot — Export to Web (per-game; replace `<slug>` with actual slug)

```powershell
cd games/<slug>
& "C:\Program Files\Godot 4\godot.windows.console.x86_64.exe" --headless --export-release "Web" "../../portal/public/games/<slug>/index.html"
```

### Godot — Run GUT Tests (run from inside the game dir)

Run from Godot editor: Addons → GUT → Run All. Or headless:

```powershell
cd games/<slug>
& "C:\Program Files\Godot 4\godot.windows.console.x86_64.exe" --headless -s addons/gut/gut_cmdln.gd
```

### NotebookLM KB Query

```powershell
$env:PYTHONUTF8=1; python "$env:USERPROFILE/.claude/skills/notebooklm/scripts/run.py" ask_question.py --question "YOUR QUESTION" --notebook-id nexus-arcade-kb
```

KB covers: game engines (Unity/Godot/GameMaker/Unreal), hyper-casual design, "juice"/feel, social media strategy, narrative inspiration from mysteries and urban legends.

NotebookLM URL: `https://notebooklm.google.com/notebook/cb00bd2d-ceff-4f06-a6f9-eeda78177381`

Re-auth if session expires (~1 year): run `auth_manager.py setup` via the same script, then capture `STORAGE_STATE_START...STORAGE_STATE_END` from output and overwrite `$env:USERPROFILE\.claude\skills\notebooklm\data\browser_state\state.json`.

## Tech Stack (Strict)

| Layer | Tech |
|-------|------|
| Game engine | Godot 4.x (GL Compatibility, 720×960 viewport) |
| Site UI framework | Next.js 14 App Router |
| Site styling | Tailwind CSS 3.4 |
| Database | Supabase (PostgreSQL) |
| Auth | Supabase Auth (Google OAuth) |
| Online multiplayer | Supabase Realtime (WebSocket channels) |
| Hosting | Railway |
| Dev flow | localhost → GitHub → Railway (auto-deploy) |

**Development style:** Vibe code — flow-based, feel-driven.
**Theme:** 80's retro aesthetic.
**Site vision:** Play Simply. Connect Deeply. Level Up Daily.

Railway project: https://railway.com/project/74047641-eaad-4212-97c1-4bb84b416ac6

## Architecture

### Game↔Portal Integration

Godot web exports land in `portal/public/games/<slug>/` and are embedded as iframes via `portal/components/GameFrame.tsx`. The iframe communicates with the portal via `postMessage`:

- **Portal → Game:** auth token handoff after Google OAuth
- **Game → Portal:** match results, score submission

### Database Schema (Supabase)

| Table | Purpose |
|-------|---------|
| `users` | Synced from `auth.users` on signup via trigger |
| `games` | Game catalog (`slug`, `status`: coming_soon/live/retired) |
| `seasons` | Per-game competitive seasons with date ranges |
| `scores` | Per-user per-game scores (mode: solo/local/online) |
| `matches` | Match records linking two players and winner |
| `achievements` | Per-user per-game achievement records |

All tables have RLS enabled. Public read allowed on all tables. Auth required for writes.

### Godot Autoloads (all games)

| Autoload | Purpose |
|----------|---------|
| `Globals` | Cross-scene shared state |
| `SFX` | Sound effects (click, win, lose, tick) |
| `FA6` | FontAwesome 6 icon helper (TTF + cheatsheet wrapper) |

### Godot Icon Rules

- Button icons: SVG as `Texture2D` — never emoji
- Label icons: `FA6` autoload — never emoji in Button/Label text

## Visual System

Single source of truth: `docs/style/nexus-arcade-style-guide.md`

**Critical:** Game colors (Godot) and portal colors (CSS) are intentionally different tones — do not normalize them:

| Context | Cyan | Purple |
|---------|------|--------|
| Godot game | `#00d4ff` | `#a855f7` |
| Portal CSS | `#00e5ff` | `#b366ff` |

Style guide change workflow: GM updates guide first → agents propagate → tester verifies.

## Gemini Gems MCP (Image Generation)

Registered in `.claude/mcp.json`. UI/Artist agent owns this — see `docs/agents/ui-artist.CLAUDE.md` for tool usage, output paths, and style prompt template.

## Agent Roles

| Agent | File | Role |
|-------|------|------|
| Game Designer | `docs/agents/game-designer.CLAUDE.md` | Mechanics, events, progression, reward systems |
| Game Dev | `docs/agents/game-dev.CLAUDE.md` | Godot mechanics, scenes, systems |
| UI/Artist | `docs/agents/ui-artist.CLAUDE.md` | Visual style, shaders, CSS, components |
| Marketer | `docs/agents/marketer.CLAUDE.md` | Social, store presence, community |
| Tester (QA) | `docs/agents/tester.CLAUDE.md` | Bug finding, style guide compliance, regression |

### Per-Project CLAUDE.md

| Project | File |
|---------|------|
| Tic Tac Toe | `games/tic-tac-toe/CLAUDE.md` |
| Portal | `portal/CLAUDE.md` |

## Project Structure

```
nexus-arcade/
  games/             — Godot projects (one dir per game slug)
  portal/            — Next.js portal app
  supabase/
    migrations/      — SQL schema + seed files (applied to cloud, never local)
  assets/            — shared assets
  docs/
    agents/          — per-agent CLAUDE.md files
    games/<slug>/    — GDD and game design docs
    style/           — nexus-arcade-style-guide.md
```
