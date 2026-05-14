Skill loaded. Text given inline — compressing directly.

# Hash Attack — Game-Specific Instructions

**Slug:** `hashattack`
**Engine:** Godot 4.x (GL Compatibility)
**Viewport:** 720×960, stretch mode `canvas_items`
**Framerate:** 60 fps target

## Mandatory References

| Resource | Location |
|----------|----------|
| Style guide (game colors) | `docs/style/nexus-arcade-style-guide.md` section 1.1 |
| GDD | `docs/games/hashattack/GDD.md` |
| Root CLAUDE.md | `CLAUDE.md` |

## Godot Export

```powershell
Set-Location "c:\Projects\claude\nexus-arcade\games\hashattack"
& "C:\Projects\godot\Godot_v4.6.2-stable_win64_console.exe" --headless --export-release "Web" "../../portal/public/games/hashattack/index.html"
```

Thread support DISABLED (`variant/thread_support=false` in export_presets.cfg). Don't re-enable — game runs on HTTP local network without HTTPS when threads off.

## Scene Structure

```
GameBoard.tscn          — main gameplay scene
MainMenu.tscn           — mode select (timer + difficulty inline)
OnlineLobby.tscn        — create/join room
GameOver.tscn           — result overlay
```

## Autoloads Used

- `Globals` — cross-scene state (`use_timer`, `timer_seconds`, `current_game_mode`, `current_user`, `jwt`)
- `SFX` — sound effects (click, win, lose, tick)
- `FA6` — FontAwesome 6 icons (`FA6.icon(name)`, `FA6.font()`)

## State & AI

- `GameState.gd` — board logic, win detection, turn management
- `TicTacToeAI.gd` — minimax (hard) + random (easy)
- Board: 9-element array, `Player.NONE` / `Player.X` / `Player.O`
- AI mark NOT always O — when player is O, AI plays as X. Use `_state.current_turn != _player_mark` to trigger AI, not `current_turn == Player.O`.

## Multiplayer

- Rooms via Supabase Realtime channel `room:{id}`
- Auth required for online mode (Google OAuth via portal bridge)
- Turn timer: 10s per-turn (configurable via Globals), off by default

## Font Glyph Rule — ORBITRON ASCII ONLY

Orbitron renders only ASCII chars (U+0020–U+007E). All other codepoints render as tofu box in GL Compatibility web export.

Banned in Label/Button using Orbitron:
- Unicode box-drawing: `�`, `─`, `│`, `┌`, etc.
- Unicode arrows/triangles: `▸`, `→`, `◄`, `►`, etc.
- Emoji, dingbat, or symbol outside basic Latin

Use instead:
- Plain ASCII: `---`, `>`, `<`, `|`, `=`
- FA6 icons: separate Label with `FA6.font()` override (see FA6 rules below)

Tessa: grep for non-ASCII strings in `.gd` files that assign `.text`. Flag every hit.

## FA6 Icons — RULES (do not repeat these mistakes)

Icon name format: cheatsheet keys have NO `fa-` prefix. Use `FA6.icon("clock")` not `FA6.icon("fa-clock")`.

Font override on buttons/labels showing FA6 icons:
```gdscript
# MUST call both: set font AND set text
var fa6 := FA6.font()
my_button.add_theme_font_override("font", fa6)
my_button.text = FA6.icon("trophy") + "  LABEL"
```

NEVER set `theme_override_fonts/font` in .tscn for nodes that show FA6 icons. Scene-level Orbitron override conflicts with script FA6 override.

FA6 icons in Button text broken in GL Compatibility web export. FA6 solid font lacks space glyph (U+0020), so `FA6.icon("x") + "  TEXT"` renders icon + tofu boxes + text. Even with `add_theme_font_override`, space renders as tofu. **Never put FA6 icon + ASCII text in same Button/Label.** Use one of:
- ASCII-only text (`">  SIGN IN"`) with Orbitron — always works
- FA6 icon in dedicated Label with FA6 font, ASCII text in separate Label with Orbitron

## SVG Icons

SVG import scale MUST be `svg/scale=4.0` (not 1.0) for crisp rendering in web export. After changing `.import` file, delete `.godot/imported/<name>.ctex` and re-export to force reimport.

## Layout — CarouselContainer children

Nodes inside `CarouselContainer` must use `anchor_top=0.0` (not `1.0`). `anchor_top=1.0` positions top edge at parent's bottom edge, extending children BELOW parent into TileBar's Y range, blocking tile button clicks.

## Layout — Z-order and Input Blocking

**Rule:** Nodes added last in scene tree receive input first (highest z-order). If a node is added dynamically (e.g., `BackgroundLayer`), call `move_child(target_node, get_child_count() - 1)` to push it behind interactive nodes.

**Critical — overlapping Control nodes block input below them.** A `Control` with `mouse_filter = STOP` (default) swallows all clicks/taps in its rect, even if it is invisible or has no visible content. Any Control covering TileBar's area prevents tap on tile buttons beneath it.

Rules to avoid tap-blocking:
- Set `mouse_filter = PASS` or `IGNORE` on any non-interactive Control (layout containers, decorative nodes).
- Dialogs/popups added as children of root must be dismissed (queue_freed or hidden) before returning input to game.
- Never leave a full-screen Control on the tree when it is not visible — set `visible = false` OR free it.
- Scenes containing `Bridge` must only be loaded via `change_scene_to_file`, NEVER added as child overlay — two Bridge instances = two JS `window.addEventListener` = duplicate postMessage handling.

## Web / HTTPS

- Godot 4 web with threads needs SharedArrayBuffer → requires `cross-origin-isolated` context (HTTPS or COOP+COEP on parent page)
- Primary fix: `variant/thread_support=false` in export_presets.cfg — game works on HTTP (local network)
- Secondary fix: next.config.js adds `COOP: same-origin` + `COEP: credentialless` to `/games/:slug` page so iframe cross-origin isolated even with threads on
- Do NOT re-enable thread support without verifying mobile local-network access works

## Auth Flow (Portal ↔ Game)

1. Game `_ready()` → `Bridge.send_game_ready()` → portal receives, calls `supabase.auth.getSession()` → sends `auth_token` to game
2. After OAuth redirect, session may not be ready when `game_ready` fires → `onAuthStateChange` in `GameFrame.tsx` catches it and sends token again
3. `PortalBridge._populate_auth(token)` → validates JWT with Supabase → populates `Globals.current_user` → emits `Globals.auth_ready`
4. `MainMenu._refresh_auth_ui()` connected to `auth_ready` → updates HUD panel

## TurnTimer Rules

- `_turn_timer.set_duration(n)` configures only — does NOT start timer.
- Call `_turn_timer.start()` explicitly for VS_AI and LOCAL modes in `_ready()`.
- Stop timer before AI think (`_turn_timer.stop()`), restart after AI places.
- ONLINE mode: start timer only on your turn (X starts on first move).

## Popup / Panel Content Padding

Programmatic `Panel` + `VBoxContainer` inside must set explicit offsets:

```gdscript
vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
vbox.offset_left   = 20
vbox.offset_top    = 16
vbox.offset_right  = -20
vbox.offset_bottom = -16
```

Without this, content sits flush against panel border.

## Auth + Nav Slots (MainMenu TileBar Row2)

Row2 is built programmatically in `_build_row2()`. Left slot: `BtnSignIn` (signed out) or `SlotProfile` (signed in). Right slots: `BtnLeaderboard`, `BtnStore` (disabled). All Row2 nodes are `Control` children of `TileBar/Row2` HBoxContainer — never overlapping, always in-flow.