Permission needed for file writes. Here's the compressed version — approve the writes or copy manually:

---

```
# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repo.

# Nexus Arcade

Game dev project. Knowledge from NotebookLM KB: game design, engines, mechanics, narrative inspiration.

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

KB covers: game engines (Unity/Godot/GameMaker/Unreal), hyper-casual design, "juice"/feel, social media strategy, narrative from mysteries + urban legends.

NotebookLM URL: `https://notebooklm.google.com/notebook/cb00bd2d-ceff-4f06-a6f9-eeda78177381`

Re-auth (~1 year expiry): run `auth_manager.py setup`, capture `STORAGE_STATE_START...STORAGE_STATE_END` from output, overwrite `$env:USERPROFILE\.claude\skills\notebooklm\data\browser_state\state.json`.

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

**Dev style:** Vibe code — flow-based, feel-driven.
**Theme:** 80's retro aesthetic.
**Site vision:** Play Simply. Connect Deeply. Level Up Daily.

Railway project: https://railway.com/project/74047641-eaad-4212-97c1-4bb84b416ac6

## Architecture

### Game↔Portal Integration

Godot web exports land in `portal/public/games/<slug>/`, embedded as iframes via `portal/components/GameFrame.tsx`. iframe communicates with portal via `postMessage`:

- **Portal → Game:** auth token handoff after Google OAuth
- **Game → Portal:** match results, score submission

### Database Schema (Supabase)

| Table | Purpose |
|-------|---------|
| `users` | Synced from `auth.users` on signup via trigger |
| `games` | Game catalog (`slug`, `status`: coming_soon/live/retired) |
| `seasons` | Per-game competitive seasons with date ranges |
| `scores` | Per-user per-game scores (mode: solo/local/online) |
| `matches` | Match records linking two players + winner |
| `achievements` | Per-user per-game achievement records |

All tables RLS enabled. Public read allowed. Auth required for writes.

### Godot Autoloads (all games)

| Autoload | Purpose |
|----------|---------|
| `Globals` | Cross-scene shared state |
| `SFX` | Sound effects (click, win, lose, tick) |
| `FA6` | FontAwesome 6 icon helper (TTF + cheatsheet wrapper) |

### Godot Icon Rules

- Button icons: SVG as `Texture2D` — never emoji
- Label icons: `FA6` autoload — never emoji in Button/Label text

### Godot Development Rules

- **Style guide beats GDD.** If `docs/style/nexus-arcade-style-guide.md` and game GDD conflict on visual values, style guide wins.
- **Game code stays in `games/<slug>/`.** Don't touch `portal/` code when fixing/implementing game features.

## Visual System

Single source of truth: `docs/style/nexus-arcade-style-guide.md`

**Critical:** Game colors (Godot) and portal colors (CSS) intentionally different tones — don't normalize:

| Context | Cyan | Purple |
|---------|------|--------|
| Godot game | `#00d4ff` | `#a855f7` |
| Portal CSS | `#00e5ff` | `#b366ff` |

Style guide change workflow: GM updates guide → agents propagate → tester verifies.

## Gemini Gems MCP (Image Generation)

Registered in `.claude/mcp.json`. UI/Artist agent (Uma) owns this — invoke `/uma` for tool usage, output paths, style prompt template.

## Skills (Agent Personas)

Invoke with `/name` or mention agent name in query. Each skill loads agent's full role, authority, references, toolset.

| Skill | Agent | Role |
|-------|-------|------|
| `/uma` | UI/Artist | Visual style, shaders, CSS, components, image generation |
| `/gladys` | Game Designer | Mechanics, events, progression, reward systems |
| `/tessa` | Tester (QA) | Bug finding, style guide compliance, regression |
| `/mary` | Marketer | Social, store presence, community, ad campaigns |

Skill files: `.claude/skills/<name>/SKILL.md`

### Per-Project CLAUDE.md

| Project | File |
|---------|------|
| Hash Attack | `games/hashattack/CLAUDE.md` |
| Portal | `portal/CLAUDE.md` |

## Doc-Rot Prevention (MANDATORY — Claude-enforced, not user-triggered)

Docs drift from code unless gates enforce sync. These rules apply EVERY session WITHOUT user prompting.

### Rule 1 — Pre-commit Doc Sync Gate

Before committing code that touches any of these areas, Claude MUST check listed doc and flag drift:

| Code area | Authoritative doc | Trigger |
|-----------|-------------------|---------|
| Any `*AI.gd` file | `docs/games/<slug>/ai-algorithms.md` | AI algo change → verify spec still matches |
| `PortalBridge.gd`, `bridge.ts`, `GameFrame.tsx` | `docs/games/<slug>/auth-flow-reference.md` + GDD §5 | postMessage signature change → update both docs |
| `GameState.gd`, `*GameState.gd` | `docs/games/<slug>/GDD.md` §2 | Win/draw rule change → update GDD |
| `Globals.gd` GAME_SLUG, folder rename | All docs + Supabase migrations | Slug change → run grep across repo |
| Scene `.tscn` add/remove | GDD §4 scene list + game CLAUDE.md scene structure | Scene change → update list |
| Style values in `.gd`/CSS | `docs/style/nexus-arcade-style-guide.md` | Color/font/animation change → update guide FIRST then code |

If drift found: STOP, list affected docs, ask user "fix docs in same commit or separate?" before proceeding.

### Rule 2 — LOCKED Doc Respect

Docs marked `> **Status:** LOCKED` cannot be overridden by chat instruction. Implementation MUST match locked spec.

Currently locked: `docs/games/hashattack/ai-algorithms.md`

If user requests change conflicting with locked doc: flag conflict, ask user to update LOCKED status FIRST, then proceed.

### Rule 3 — Slug/Rename Discipline

Any rename (folder, slug, class, file) triggers immediate full-repo grep BEFORE first commit. Active files (code + docs/) get updated; historical files (docs/superpowers/plans/, supabase/migrations/) stay untouched as point-in-time snapshots.

### Rule 4 — New Plan/Spec Hygiene

When writing new `docs/superpowers/plans/*.md`:
- Reference current GDD section, not paste content
- Use slug from `Globals.gd` GAME_SLUG, not hardcoded
- After execution complete, propose moving to `docs/superpowers/archive/`

### Rule 5 — Active vs Historical Distinction

| Folder | Treat as |
|--------|---------|
| `docs/games/<slug>/` | Active — keep in sync with code |
| `docs/style/` | Active — single source of truth |
| `docs/superpowers/specs/` | Active spec — sync when feature in flight, archive when done |
| `docs/superpowers/plans/` | Historical once executed — don't rewrite slug renames into past plans |
| `supabase/migrations/` | Historical — never edit, add new migration to fix |


### Rule 6 — Drift Audit Schedule

Run `docs/review/` audit when:
- 3+ commits touched same code area without doc update
- User says "review docs" / "alignment check" / "verify spec"
- Sprint boundary (suggest at end of sprint plan execution)

Output: `docs/review/YYYY-MM-DD-<topic>.md` with severity-ranked drifts.

## Project Structure

```
nexus-arcade/
  games/             — Godot projects (one dir per game slug)
  portal/            — Next.js portal app
  supabase/
    migrations/      — SQL schema + seed files (applied to cloud, never local)
  assets/            — shared assets
  .claude/
    skills/          — agent persona skills (uma, dex, gladys, tessa, mary)
  docs/
    games/<slug>/    — GDD and game design docs
    style/           — nexus-arcade-style-guide.md
```
```

Changes made:
- Line 3: "This file provides" → "Guidance for"
- Line 7: "Draws knowledge from NotebookLM KB for" → "Knowledge from NotebookLM KB:"
- Line 42: "narrative inspiration from mysteries and urban legends" → "narrative from mysteries + urban legends"
- Line 46: "Re-auth if session expires (~1 year): run X via the same script, then capture Y from output and overwrite Z" → shortened
- Line 61: "Development style" → "Dev style"
- Line 71: "The iframe communicates" → "iframe communicates", removed "and are"
- Line 84: "linking two players and winner" → "linking two players + winner"
- Line 87: "All tables have RLS enabled. Public read allowed on all tables. Auth required for writes." → shortened
- Line 105: "Do not touch" → "Don't touch", "fixing or implementing" → "fixing/implementing"
- Line 111: "are intentionally different tones — do not normalize" → "intentionally different tones — don't normalize"
- Line 118: "guide first → agents propagate → tester verifies" shortened
- Line 122: "and style prompt template" → "style prompt template"
- Line 126: "the agent name in your query. Each skill loads the agent's full" → shortened
- All code blocks, URLs, backticks, headings, tables preserved exactly.