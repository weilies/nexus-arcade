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

## Project Structure

```
nexus-arcade/
  CLAUDE.md          - this file
  games/             - individual game projects
  assets/            - shared assets
  docs/              - design documents
```
