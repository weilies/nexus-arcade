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

**Thread support is DISABLED** (`variant/thread_support=false` in export_presets.cfg). Do not re-enable — the game runs on HTTP local network without HTTPS when threads are off.

## Scene Structure

```
GameBoard.tscn          — main gameplay scene
MainMenu.tscn           — mode select (timer + difficulty inline) + HUD slide panel
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
- AI mark is NOT always O — when player is O, AI plays as X. Use `_state.current_turn != _player_mark` to trigger AI, not `current_turn == Player.O`.

## Multiplayer

- Rooms via Supabase Realtime channel `room:{id}`
- Auth required for online mode (Google OAuth via portal bridge)
- Turn timer: 10s per-turn (configurable via Globals), off by default

## Font Glyph Rule — ORBITRON ASCII ONLY

**Orbitron renders only ASCII characters (U+0020–U+007E).** Every other codepoint renders as a tofu box in GL Compatibility web export.

Banned in any Label/Button using Orbitron:
- Unicode box-drawing: `�`, `─`, `│`, `┌`, etc.
- Unicode arrows/triangles: `▸`, `→`, `◄`, `►`, etc.
- Any emoji, dingbat, or symbol outside basic Latin

Use instead:
- Plain ASCII: `---`, `>`, `<`, `|`, `=`
- FA6 icons: use a **separate** Label with `FA6.font()` override (see FA6 rules below)

Tessa: grep for non-ASCII strings in any `.gd` file that assigns `.text`. Flag every hit.

## FA6 Icons — RULES (do not repeat these mistakes)

**Icon name format:** cheatsheet keys have NO `fa-` prefix. Use `FA6.icon("clock")` not `FA6.icon("fa-clock")`.

**Font override on buttons/labels showing FA6 icons:**
```gdscript
# MUST call both: set font AND set text
var fa6 := FA6.font()
my_button.add_theme_font_override("font", fa6)
my_button.text = FA6.icon("trophy") + "  LABEL"
```

**NEVER set `theme_override_fonts/font` in the .tscn for any node that will show FA6 icons.** The scene-level Orbitron override conflicts with the script FA6 override.

**FA6 icons in Button text are BROKEN in GL Compatibility web export.** FA6 solid font lacks the space glyph (U+0020), so `FA6.icon("x") + "  TEXT"` renders icon + tofu boxes + text. Even with `add_theme_font_override`, the space renders as tofu. **Rule: never put FA6 icon + ASCII text in the same Button/Label.** Use one of:
- ASCII-only text (`">  SIGN IN"`) with Orbitron — always works
- FA6 icon in a dedicated Label with FA6 font, ASCII text in a separate Label with Orbitron

## SVG Icons

SVG import scale MUST be `svg/scale=4.0` (not 1.0) for crisp rendering in web export. After changing `.import` file, delete `.godot/imported/<name>.ctex` and re-export to force reimport.

## Layout — CarouselContainer children

Nodes inside `CarouselContainer` must use `anchor_top=0.0` (not `1.0`). `anchor_top=1.0` positions the top edge at the parent's bottom edge, causing children to extend BELOW the parent into TileBar's Y range, blocking tile button clicks.

## Layout — Z-order

Nodes added last in the scene tree receive input first. If a new child node is added dynamically (e.g., BackgroundLayer), call `move_child($BtnExpand, get_child_count() - 1)` to keep the overlay button on top.

## Web / HTTPS

- Godot 4 web with threads needs SharedArrayBuffer → requires `cross-origin-isolated` context (HTTPS or COOP+COEP on parent page)
- **Primary fix:** `variant/thread_support=false` in export_presets.cfg — game works on HTTP (local network)
- **Secondary fix:** next.config.js adds `COOP: same-origin` + `COEP: credentialless` to `/games/:slug` page so iframe is cross-origin isolated even with threads on
- Do NOT re-enable thread support without also verifying mobile local-network access works

## Auth Flow (Portal ↔ Game)

1. Game `_ready()` → `Bridge.send_game_ready()` → portal receives, calls `supabase.auth.getSession()` → sends `auth_token` to game
2. After OAuth redirect, session may not be ready when `game_ready` fires → `onAuthStateChange` in `GameFrame.tsx` catches it and sends token again
3. `PortalBridge._populate_auth(token)` → validates JWT with Supabase → populates `Globals.current_user` → emits `Globals.auth_ready`
4. `MainMenu._refresh_auth_ui()` connected to `auth_ready` → updates HUD panel

## TurnTimer Rules

- `_turn_timer.set_duration(n)` only configures — it does NOT start the timer.
- Call `_turn_timer.start()` explicitly for VS_AI and LOCAL modes in `_ready()`.
- Stop timer before AI think (`_turn_timer.stop()`), restart after AI places.
- Timer in ONLINE mode: only start on your turn (X starts on first move).

## Popup / Panel Content Padding

Any programmatic `Panel` + `VBoxContainer` inside it must set explicit offsets:

```gdscript
vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
vbox.offset_left   = 20
vbox.offset_top    = 16
vbox.offset_right  = -20
vbox.offset_bottom = -16
```

Without this, content sits flush against the panel border.

## HUD Slide Panel (MainMenu)

Right-edge drawer. `BtnExpand` toggles. `HUDPanel` slides in/out via `tween_property(offset_left)`. Contains: `SlotProfile` (signed in) OR `BtnSignIn` (signed out), `BtnLeaderboard`, `BtnMarketplace` (disabled). Add new slots here as features grow — do not clutter the main HUD.
