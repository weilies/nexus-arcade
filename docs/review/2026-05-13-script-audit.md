# Godot Script Audit — 2026-05-13

> **Reviewer:** Claude Sonnet 4.6 (1M)
> **Files read:** All 17 scripts + 5 scene .gd files (22 total)
> **Mode:** Read-only review. Code fixes listed, not applied (confirm each).

---

## Summary Table

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | **CRITICAL** | `SupabaseClient.gd` | `_ws` never nulled on WS close → reconnect silently ignored |
| 2 | **HIGH** | `OnlineLobby.gd` | Shared `rest_completed` signal — any REST response triggers lobby handler |
| 3 | **HIGH** | `GameOver.gd` | `_board_ref` dangling reference risk |
| 4 | **MED** | `SupabaseClient.gd` | Single `_http` node for fire-and-forget — concurrent calls queue/fail |
| 5 | **MED** | `SFX.gd` | Missing `tick()` sound (style guide §5 lists as v1) |
| 6 | **MED** | `GameBoard.gd:561` | `LblGameInfo` font_size 22 — below 28px style guide min |
| 7 | **MED** | `ModeCarousel.gd:9` | Mode id `"ephemerate"` — differs from docs ("ephemeral") |
| 8 | **LOW** | `ModeTile.gd` | Dead code — `corner_radius` theme constant override does nothing |
| 9 | **LOW** | `ModeTile.gd` | Text `alignment = LEFT`, icon `alignment = CENTER` — mismatched |
| 10 | **LOW** | `TurnTimer.gd:7` | Default `_duration = 30.0` misleading (callers use 3/6/9) |
| 11 | **INFO** | `SFX.gd` | No `lose()` call anywhere in codebase — sound exists but unwired |

---

## Detailed Findings

### 1. CRITICAL — WebSocket never nulled on close [SupabaseClient.gd:93](../../games/hashattack/scripts/SupabaseClient.gd#L93)

```gdscript
WebSocketPeer.STATE_CLOSED:
    _ws_ready = false
    # _ws is NOT set to null
```

`connect_realtime()` returns early if `_ws != null`:
```gdscript
func connect_realtime(channel_name: String) -> void:
    _pending_channels.append(channel_name)
    if _ws != null:   # ← dead WS, never null → always returns early
        return
```

**Impact:** If WS drops mid-game (network hiccup, server timeout), `connect_realtime` can never reconnect. Online mode silently breaks — no error, no recovery.

**Fix:**
```gdscript
WebSocketPeer.STATE_CLOSED:
    _ws_ready = false
    _ws = null   # ← allow reconnect
```

---

### 2. HIGH — Shared `rest_completed` signal in OnlineLobby [OnlineLobby.gd:19](../../games/hashattack/scenes/OnlineLobby.gd#L19)

```gdscript
Globals.supabase.rest_completed.connect(_on_rest)
```

`rest_completed` fires for every REST call through `Globals.supabase` — not just OnlineLobby's own calls. If any other code path fires a REST call while OnlineLobby is active (e.g., leaderboard fetch, streak fetch), `_on_rest` receives it and the phase state machine processes wrong data.

`_exit_tree` disconnects cleanly ✓ — but the race window is non-zero.

**Fix:** OnlineLobby should use its own `SupabaseClient` instance (already does for PortalBridge) OR filter by request tag. Simplest: pass a callback to the async helpers rather than using the shared signal.

---

### 3. HIGH — `_board_ref` dangling reference [GameOver.gd:61](../../games/hashattack/scenes/GameOver.gd#L61)

```gdscript
func _on_play_again() -> void:
    SFX.click()
    _board_ref.reset_for_replay()   # ← crashes if _board_ref freed
    queue_free()
```

`_board_ref` is the GameBoard passed at GameOver setup. If GameBoard is freed before `_on_play_again` fires (e.g., scene change), this crashes with "Invalid get index 'reset_for_replay' on base 'previously freed instance'".

**Verify:** How GameOver is shown. If GameBoard calls `add_child(game_over_scene)` then frees itself, `_board_ref` is immediately invalid. Safe only if GameBoard remains alive while GameOver is visible.

**Fix:** Add null guard:
```gdscript
func _on_play_again() -> void:
    SFX.click()
    if is_instance_valid(_board_ref):
        _board_ref.reset_for_replay()
    queue_free()
```

---

### 4. MED — Single `_http` node for concurrent fire-and-forget [SupabaseClient.gd:29](../../games/hashattack/scripts/SupabaseClient.gd#L29)

`get_rows`, `insert_row`, `patch_row` share one `_http` node. HTTPRequest queues one request at a time — second request while first is pending silently fails (returns `RESULT_CANT_CONNECT`). GameBoard calls both `broadcast` + `patch_row` in sequence — if `_http` is busy, patch is dropped.

The async helpers (`_async_get`, `_async_post`) correctly create fresh `HTTPRequest` nodes per call ✓. Fire-and-forget methods should do the same.

**Fix:** Extract disposable HTTPRequest pattern:
```gdscript
func _fire(method: int, path: String, headers: PackedStringArray, body: String = "") -> void:
    var h := HTTPRequest.new()
    add_child(h)
    h.request_completed.connect(func(_r, _c, _h, _b): h.queue_free())
    h.request(_url + path, headers, method, body)
```

---

### 5. MED — Missing `SFX.tick()` [SFX.gd](../../games/hashattack/scripts/SFX.gd)

Style guide §5 lists "Turn timer tick — ≤5s remaining — v1" as a priority sound. `SFX` has `click()`, `win()`, `lose()` — no `tick()`. TurnTimer emits `tick` signal (every second), GameBoard connects to it for ring update only — never calls SFX.

**Fix:** Add to SFX.gd:
```gdscript
func tick() -> void:
    _play(_make_tone(440.0, 0.04, 0.15))
```

Wire in GameBoard `_on_timer_tick()`:
```gdscript
func _on_timer_tick(seconds_left: int) -> void:
    if seconds_left <= 5:
        SFX.tick()
    ...
```

---

### 6. MED — `LblGameInfo` font_size 22 hardcoded [GameBoard.gd:561](../../games/hashattack/scenes/GameBoard.gd#L561)

```gdscript
lbl.add_theme_font_size_override("font_size", 22)
```

Style guide §2.2 minimum for status labels: 28px. This label shows "BLITZ", "EASY", "HARD" etc.

**Fix:** Change `22` → `28`.

---

### 7. MED — Mode ID "ephemerate" differs from docs [ModeCarousel.gd:9](../../games/hashattack/scripts/ModeCarousel.gd#L9)

```gdscript
{ "name": "Ephemerate", "id": "ephemerate" },
```

GDD, auth-flow-reference, and style guide call it "Ephemeral". Code uses "ephemerate" consistently (ModeCarousel, GameBoard, ModePreview all match). Not a runtime bug — consistent internally. But future AI agents reading GDD will write code checking `"ephemeral"` and fail silently.

**Two options:**
- **A.** Rename in code to "ephemeral" (requires updating GameBoard, ModePreview, ModeCarousel) — more work, clean
- **B.** Add note to GDD: "Internal mode ID is `ephemerate` (not `ephemeral`)" — quick, truthful

Recommend **A** (code rename) since "ephemerate" is not a real word.

---

### 8. LOW — Dead code in ModeTile [ModeTile.gd:16](../../games/hashattack/scripts/ModeTile.gd#L16)

```gdscript
add_theme_constant_override("corner_radius", 0)
```

`corner_radius` is a `StyleBoxFlat` property, not a theme constant. This override silently does nothing. Delete it.

---

### 9. LOW — Mismatched alignment in ModeTile [ModeTile.gd:18](../../games/hashattack/scripts/ModeTile.gd#L18)

```gdscript
icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
alignment = HORIZONTAL_ALIGNMENT_LEFT
```

Button text aligns left, icon centers. Tile labels like "LEADERBOARD" appear left-justified while icon is centered — visual inconsistency.

**Fix:** `alignment = HORIZONTAL_ALIGNMENT_CENTER`

---

### 10. LOW — TurnTimer default duration misleading [TurnTimer.gd:7](../../games/hashattack/scripts/TurnTimer.gd#L7)

```gdscript
var _duration: float = 30.0
```

No caller sets duration to 30. `Globals.timer_seconds` valid values: 0 (off), 3, 6, 9. `set_duration` is called before `start()` so the 30 default is never used in practice. Still confusing — implies 30s was an old spec (it was per original GDD).

**Fix:** `var _duration: float = 9.0` (max valid) or add a comment:
```gdscript
var _duration: float = 9.0  # overridden by set_duration() before start()
```

---

### 11. INFO — `SFX.lose()` never called

`SFX.lose()` exists and generates a descending tone sequence. Grep finds no callsite. Either:
- GameBoard calls `SFX.win()` for winner but nothing for loser (correct design — only one player is in the session)
- OR it was planned for a "you lost" notification that was never wired

Not a bug — just unused. Delete or wire to GameOver for the losing player in online mode.

---

## What's Clean (positive findings)

- **Signal disconnect discipline:** `_exit_tree` properly disconnects all signals in GameBoard and OnlineLobby ✓
- **Async HTTPRequest cleanup:** `_async_get/_async_post` create + `queue_free` nodes correctly ✓
- **TurnTimer null guards:** All `if _label:` guards before label access ✓
- **BackgroundLayer:** `mouse_filter = IGNORE` correctly set — doesn't block input ✓
- **`_game_over_fired` flag in GameBoard:** Prevents double-fire on simultaneous result detection ✓
- **SFX.gd:** Self-cleaning audio players via `p.finished.connect(p.queue_free)` ✓
- **JWT decode in OnlineLobby:** Client-side only for room creation user_id lookup — server validates separately ✓
- **`validate_session` in SupabaseClient:** Two-step (auth user → public.users profile) correctly returns empty on failure ✓

---

## Recommended Fix Sequence

| Priority | Fix | File | Risk |
|----------|-----|------|------|
| 1 | Null `_ws` on STATE_CLOSED | SupabaseClient.gd:94 | Low — 1 line |
| 2 | Null guard on `_board_ref` | GameOver.gd:61 | Low — 2 lines |
| 3 | Fix fire-and-forget HTTP | SupabaseClient.gd:29-43 | Med — refactor |
| 4 | Rename "ephemerate" → "ephemeral" | ModeCarousel + GameBoard + ModePreview | Med — 10 lines |
| 5 | Add SFX.tick() + wire | SFX.gd + GameBoard.gd | Low |
| 6 | Fix LblGameInfo font_size | GameBoard.gd:561 | Low — 1 line |
| 7 | Fix ModeTile alignment | ModeTile.gd:20 | Low — 1 line |
| 8 | Delete dead corner_radius override | ModeTile.gd:16 | Low — 1 line |
| 9 | Fix TurnTimer default | TurnTimer.gd:7 | Low — 1 line |

---

## Next Session

Session #4 — Portal code audit (Next.js components, API routes, data layer).
