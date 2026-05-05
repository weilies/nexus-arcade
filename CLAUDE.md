# Nexus Arcade

Game development project. Draws knowledge from NotebookLM KB for game design, engines, mechanics, and narrative inspiration.

## NotebookLM Integration

Notebook ID: `nexus-arcade-kb`
Notebook URL: `https://notebooklm.google.com/notebook/cb00bd2d-ceff-4f06-a6f9-eeda78177381`

KB covers: game engines (Unity/Godot/GameMaker/Unreal), programming basics, hyper-casual design, "juice"/feel, social media strategy, narrative inspiration from mysteries and urban legends.

### Query the KB

```bash
PYTHONUTF8=1 python "C:/Users/WeiTatCHOK/.claude/skills/notebooklm/scripts/run.py" ask_question.py --question "YOUR QUESTION" --notebook-id nexus-arcade-kb
```

### Re-auth if session expires (~1 year)

```bash
PYTHONUTF8=1 python "C:/Users/WeiTatCHOK/.claude/skills/notebooklm/scripts/run.py" auth_manager.py setup
```

After setup, Claude must capture STORAGE_STATE_START...STORAGE_STATE_END from output
and overwrite `C:\Users\WeiTatCHOK\.claude\skills\notebooklm\data\browser_state\state.json`.

## Tech Stack (Strict)

| Layer | Tech |
|-------|------|
| Game engine | Godot 4.x |
| Site UI framework | Next.js 14 |
| Site styling | Tailwind CSS |
| Database | Supabase (PostgreSQL) |
| Auth | Supabase Auth (social SSO: Google OAuth) |
| Online multiplayer | Supabase Realtime (WebSocket channels) |
| Hosting | Railway (portal serves Godot web export as static files) |
| Dev flow | localhost → GitHub (code) → Railway (deploy) |

**Development style:** Vibe code for both web dev and game dev (flow-based, feel-driven).

**Theme:** 80's retro aesthetic.

**Site vision:** Play Simply. Connect Deeply. Level Up Daily.

Railway project: https://railway.com/project/74047641-eaad-4212-97c1-4bb84b416ac6

Godot web exports live in `portal/public/games/<slug>/` — served by Next.js, embedded via iframe in portal game pages.

## Agent Roles

This project uses specialized AI agents, each with its own CLAUDE.md:

| Agent | File | Role |
|-------|------|------|
| Game Designer | `docs/agents/game-designer.CLAUDE.md` | Mechanics, events, progression, reward systems, hooks |
| Game Dev | `docs/agents/game-dev.CLAUDE.md` | Godot mechanics, scenes, systems |
| UI/Artist | `docs/agents/ui-artist.CLAUDE.md` | Visual style, shaders, CSS, components |
| Marketer | `docs/agents/marketer.CLAUDE.md` | Social, store presence, community |
| Tester (QA) | `docs/agents/tester.CLAUDE.md` | Bug finding, style guide compliance, regression |

### Per-Project CLAUDE.md

| Project | File | Scope |
|---------|------|-------|
| Tic Tac Toe | `games/tic-tac-toe/CLAUDE.md` | Game-specific conventions, known issues |
| Portal | `portal/CLAUDE.md` | Next.js app conventions, build commands |

### Style Guide

The single source of truth for all visual values: `docs/style/nexus-arcade-style-guide.md`

**Workflow:**
1. GM identifies need or discrepancy
2. Style guide updated first (plain-language direction from GM)
3. Agents propagate to their domains
4. Tester verifies compliance

## Project Structure

```
nexus-arcade/
  CLAUDE.md          - this file
  games/             - individual game projects (Godot projects)
  portal/            - Next.js portal app (deployed to Railway)
  supabase/          - Supabase config/migrations
  assets/            - shared assets
  docs/              - design documents
```
