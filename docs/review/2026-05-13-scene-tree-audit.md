# Scene Tree Audit — 2026-05-13

> **Reviewer:** Claude Sonnet 4.6 (1M)
> **Scope:** All 5 Godot scenes — read-only. No .tscn edits (UID refs risk). Fix in editor.
> **Reference:** `docs/style/nexus-arcade-style-guide.md` §2.2 (type scale), game `CLAUDE.md`

---

## Scene Inventory

| Scene | Nodes | Notes |
|-------|-------|-------|
| `MainMenu.tscn` | 27 | Most complex; partial dynamic build |
| `GameBoard.tscn` | 30 | Grid + scoring |
| `GameOver.tscn` | 11 | Clean |
| `OnlineLobby.tscn` | 12 | Clean |
| `LeaderboardScene.tscn` | 6 | Minimal, clean |

---

## Issues

### CRITICAL — HUD Slide Panel not implemented

**game CLAUDE.md says:**
> Right-edge drawer. `BtnExpand` toggles. `HUDPanel` slides in/out via `tween_property(offset_left)`. Contains: `SlotProfile` (signed in) OR `BtnSignIn` (signed out), `BtnLeaderboard`, `BtnMarketplace` (disabled).

**Reality:** `BtnExpand` and `HUDPanel` don't exist anywhere — not in `MainMenu.tscn`, not built in `MainMenu.gd`. The HUD expand panel is **entirely unimplemented**. CLAUDE.md was written anticipating a feature that was never built.

**GDD §4 also references it:**
> `[>]` button (top-right), expand panel slides from right edge.

**Impact:** Any future agent reading CLAUDE.md will attempt to reference `$BtnExpand` or `$HUDPanel` and get null errors.

**Fix:** Either implement it, or update CLAUDE.md + GDD §4 to note it's deferred. Pick one — don't leave phantom spec.

---

### HIGH — Font sizes in .tscn override style guide minimums (9 violations)

`.tscn` `theme_override_font_sizes` hardcoded values take precedence over `ArcadeTheme.tres`. Style guide §2.2 Godot minimums (at 720×960): help text 24px, button labels 30px, body 28px.

| Node | Actual | Required | Severity |
|------|--------|----------|----------|
| `CarouselContainer/LblModeName` | 22px | 24px (help) | MED |
| `CarouselContainer/TimerRow/BtnTimer/HBoxTimer/LblClockIcon` | 14px | 24px (help) | HIGH |
| `CarouselContainer/TimerRow/BtnTimer/HBoxTimer/LblTimer` | 14px | 24px (help) | HIGH |
| `CarouselContainer/DifficultyRow/BtnDifficulty` | 14px | 30px (button) | HIGH |
| `TileBar/Row1/Btn1P` | 16px | 30px (button) | HIGH |
| `TileBar/Row1/Btn2P` | 16px | 30px (button) | HIGH |
| `TileBar/Row1/BtnOnline` | 16px | 30px (button) | HIGH |
| `TileBar/Row1/BtnHelp` | 16px | 30px (button) | HIGH |
| `TileBar/Row2/BtnLeaderboard` | 14px | 30px (button) | HIGH |
| `TileBar/Row2/BtnStore` | 14px | 30px (button) | HIGH |

**Note:** Tile buttons (Btn1P etc.) are 96×96px. At 30px font, text + icon may need layout adjustment. Test on real device after fix.

**Fix:** In Godot editor, select each node → Inspector → Theme Overrides → Font Sizes → update value.

---

### HIGH — `_refresh_timer_visibility()` always shows timer (logic bug)

**Code [MainMenu.gd:146](../../games/hashattack/scenes/MainMenu.gd#L146):**
```gdscript
func _refresh_timer_visibility() -> void:
    $CarouselContainer/TimerRow.visible = true
```

Always `true`. Called on `mode_changed`. Intent (per GDD §4): timer row hidden in Ultimate mode. Never hidden anywhere.

**Fix:**
```gdscript
func _refresh_timer_visibility() -> void:
    $CarouselContainer/TimerRow.visible = (_current_game_mode != "ultimate")
```

---

### MED — Duplicate `Bridge` (PortalBridge) in two scenes

Both `MainMenu.tscn` and `GameBoard.tscn` have a child `Node` named `Bridge` with `PortalBridge.gd` script. This is a per-scene pattern (not autoload). Two listeners can be active simultaneously only if old scene isn't freed — Godot's `change_scene_to_file` does free old scene, so this is safe during normal navigation.

**Risk:** If a scene is added as overlay (popup, sub-scene) rather than replacing root, two Bridge instances would coexist → duplicate `window.addEventListener` in JS → duplicate postMessage handling → double score submissions.

**Recommendation:** Document the pattern explicitly in `games/hashattack/CLAUDE.md`:
> "Bridge is a per-scene Node, not an autoload. Each scene frees its Bridge on scene change. Never add Bridge-containing scenes as child overlays — use `change_scene_to_file` only."

---

### MED — Generic node names impede editor navigation

| Node | Scene | Recommendation |
|------|-------|---------------|
| `VBoxContainer` | GameBoard, GameOver, OnlineLobby | Rename: `BoardLayout`, `ResultLayout`, `LobbyLayout` |
| `ColorRect` | All scenes | Rename: `Background` |
| `HBoxContainer` (unnamed row) | — | All have names in this codebase — OK |

These are cosmetic but matter when future agents or you navigate the scene tree in editor. Godot editor shows node names in the tree panel.

**Fix:** Rename in editor (F2 on node). Script `@onready` refs by node name must also update.

---

### LOW — `TimerRow` wraps single Button 5 levels deep

```
TimerRow (Control)
  └─ BtnTimer (Button)
       └─ HBoxTimer (HBoxContainer)
            ├─ LblClockIcon (Label)   ← FA6 icon
            └─ LblTimer (Label)       ← "TIMER: OFF"
```

`TimerRow` (Control) exists only to hold `BtnTimer`. It adds nothing — `BtnTimer` could be direct child of `CarouselContainer`. The extra `Control` wrapper adds layout complexity with no benefit.

**Fix:** Delete `TimerRow`, reparent `BtnTimer` directly to `CarouselContainer`. Update `@onready` path in `MainMenu.gd:31-32`:
```gdscript
# Before:
@onready var _btn_timer: Button = $CarouselContainer/TimerRow/BtnTimer
@onready var _lbl_timer: Label = $CarouselContainer/TimerRow/BtnTimer/HBoxTimer/LblTimer
@onready var _lbl_clock_icon: Label = $CarouselContainer/TimerRow/BtnTimer/HBoxTimer/LblClockIcon
# After:
@onready var _btn_timer: Button = $CarouselContainer/BtnTimer
@onready var _lbl_timer: Label = $CarouselContainer/BtnTimer/HBoxTimer/LblTimer
@onready var _lbl_clock_icon: Label = $CarouselContainer/BtnTimer/HBoxTimer/LblClockIcon
```

---

### LOW — Row2 auth slot fully dynamic vs partially dynamic

`_build_row2()` in `MainMenu.gd` programmatically builds all auth-related nodes (BtnSignIn, SlotProfile, BtnSignOut). This means:
- Auth UI invisible in Godot editor's 2D viewport
- Can't visually preview layout
- No scene validation (UID tracking)

Not a bug, but makes visual iteration slower. If auth UI changes frequently, consider moving to a static sub-scene (e.g., `AuthSlot.tscn`) instantiated in `TileBar/Row2`.

---

### INFO — `GameBoard.tscn` missing TurnTimer node

`TurnTimer.gd` exists as a script but no `TurnTimer` node appears in `GameBoard.tscn`. Must be added programmatically in `GameBoard.gd`. Verify:

```bash
grep -n "TurnTimer\|_turn_timer" games/hashattack/scenes/GameBoard.gd | head -5
```

If dynamic: expected. If missing entirely: timer feature broken.

---

## What's Clean

- `GameOver.tscn` — minimal, well-named, no issues
- `OnlineLobby.tscn` — clean structure, good names
- `LeaderboardScene.tscn` — minimal, correct
- All scenes correctly use `Control` root (not Node2D) — correct for UI
- `Bridge` node naming consistent across scenes
- SVG icons used (not emoji) ✓ — matches icon rules

---

## Fix Priority

| Priority | Fix | Location | Effort |
|----------|-----|----------|--------|
| 1 | Decide HUD panel: implement or document as deferred | CLAUDE.md + GDD | 30 min (doc) / 2h (implement) |
| 2 | Fix `_refresh_timer_visibility()` | MainMenu.gd:146 | 3 min |
| 3 | Fix 10 font size violations | Godot editor | 15 min |
| 4 | Document Bridge-per-scene pattern | game CLAUDE.md | 5 min |
| 5 | Rename generic node names | Godot editor | 10 min |
| 6 | Flatten TimerRow | Godot editor + MainMenu.gd | 15 min |

---

## Next Session

Session #2 — Godot script audit: `.gd` logic review (signal patterns, memory leaks, dead code, null guards).
