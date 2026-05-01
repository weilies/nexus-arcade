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

## Tech Stack

| Layer | Tech |
|-------|------|
| Game engine | Godot 4.x |
| Portal | Next.js 14 + Supabase SSR |
| Auth | Supabase Auth (Google OAuth provider) |
| Online multiplayer | Supabase Realtime (WebSocket channels) |
| DB | Supabase (PostgreSQL) |
| Hosting | Railway (portal serves Godot web export as static files) |
| Dev flow | localhost → GitHub (code) → Railway (deploy) |

Railway project: https://railway.com/project/74047641-eaad-4212-97c1-4bb84b416ac6

Godot web exports live in `portal/public/games/<slug>/` — served by Next.js, embedded via iframe in portal game pages.

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
