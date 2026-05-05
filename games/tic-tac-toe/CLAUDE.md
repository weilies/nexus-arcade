# Tic Tac Toe — Game-Specific Instructions

**Slug:** `tic-tac-toe`
**Engine:** Godot 4.x (GL Compatibility)
**Viewport:** 720×960, stretch mode `canvas_items`
**Framerate:** 60 fps target

## Mandatory References

| Resource | Location |
|----------|----------|
| Style guide (game colors) | `docs/style/nexus-arcade-style-guide.md` section 1.1 |
| GDD | `docs/games/tic-tac-toe/GDD.md` |
| Game Dev agent | `docs/agents/game-dev.CLAUDE.md` |
| Root CLAUDE.md | `CLAUDE.md` |

## Critical Values (Style Guide Overrides)

These values in the current code DO NOT match the style guide and should be corrected:

| What | Current (wrong) | Style Guide (correct) |
|------|-----------------|----------------------|
| X mark color (GameBoard.gd:200) | `#00f2ff` | `#00d4ff` |
| Background (GameBoard.tscn:18) | `Color(0.043, 0.043, 0.082, 1)` ≈ `#0B0B15` | `Color("#0a0a1a")` |

## Scene Structure

```
GameBoard.tscn          — main gameplay scene
MainMenu.tscn           — mode select
AIDifficultySelect.tscn — easy/hard picker
OnlineLobby.tscn        — create/join room
GameOver.tscn           — result overlay
```

## Autoloads Used

- `Globals` — cross-scene state
- `SFX` — sound effects (click, win, lose, tick)
- `FA6` — FontAwesome 6 icons (labels only)

## State & AI

- `GameState.gd` — board logic, win detection, turn management
- `TicTacToeAI.gd` — minimax (hard) + random (easy)
- Board: 9-element array, `Player.NONE` / `Player.X` / `Player.O`

## Multiplayer

- Rooms via Supabase Realtime channel `room:{id}`
- Auth required for online mode (Google OAuth via portal bridge)
- Turn timer: 30s, auto-forfeit on timeout

## Color Fixes Needed

1. In `scenes/GameBoard.gd` line 200: change `Color("#00f2ff")` → `Color("#00d4ff")`
2. In `scenes/GameBoard.tscn` line 18: change `color = Color(0.043, 0.043, 0.082, 1)` → `color = Color("#0a0a1a")`
3. Verify `scenes/GameBoard.gd` line 203: `Color("#a855f7")` already matches — no change needed

## Export

```powershell
cd games/tic-tac-toe
& "C:\Program Files\Godot 4\godot.windows.console.x86_64.exe" --headless --export-release "Web" "../../portal/public/games/tic-tac-toe/index.html"
```
