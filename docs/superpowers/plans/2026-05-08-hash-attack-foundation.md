# #HashAttack! Foundation Weekend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename game to #HashAttack!, add membership point system with per-mode streak multipliers, Godot SSO detection, leaderboard scene, and portal admin/profile pages.

**Architecture:** DB migration adds 6 tables + 2 security-definer RPCs on Supabase cloud. Godot auth flow: portal sends JWT on `game_ready` → `PortalBridge` validates with `/auth/v1/user` → populates `Globals.current_user`. Points awarded via `award_win_points` RPC after AI/online wins; streak badge always visible in GameBoard; portal profile + admin pages read new tables.

**Tech Stack:** Godot 4.x GDScript, Supabase PostgreSQL + REST RPCs, Next.js 14 App Router, Tailwind CSS, @supabase/ssr

---

## File Map

| File | New / Modified | Purpose |
|------|---------------|---------|
| `supabase/migrations/007_membership_scoring.sql` | New | All tables, RPCs, RLS, rebrand UPDATE |
| `games/tic-tac-toe/scripts/Globals.gd` | Modified | Add current_user, current_game_id, current_streak, auth_ready signal |
| `games/tic-tac-toe/scripts/SupabaseClient.gd` | Modified | Async helper + 6 new public methods |
| `games/tic-tac-toe/scripts/PortalBridge.gd` | Modified | Wire auth_token → validate → populate Globals |
| `games/tic-tac-toe/scenes/MainMenu.gd` | Modified | Auth-aware UI, rebrand title, leaderboard button |
| `games/tic-tac-toe/scenes/MainMenu.tscn` | Modified (editor) | Add Bridge node, ProfileRow, BtnSignIn, BtnLeaderboard |
| `games/tic-tac-toe/scenes/GameBoard.gd` | Modified | Streak badge state, win/loss RPC calls, pts popup |
| `games/tic-tac-toe/scenes/GameBoard.tscn` | Modified (editor) | Add StreakBadge node group |
| `games/tic-tac-toe/scenes/GameOver.gd` | Modified | Streak display, pts earned, milestone banner |
| `games/tic-tac-toe/scenes/GameOver.tscn` | Modified (editor) | Add LblStreakDisplay, LblPtsEarned, MilestoneBanner |
| `games/tic-tac-toe/scenes/LeaderboardScene.gd` | New | Fetch + display top-20 leaderboard |
| `games/tic-tac-toe/scenes/LeaderboardScene.tscn` | New (editor) | Scene tree for leaderboard |
| `games/tic-tac-toe/tests/test_scoring.gd` | New | GUT unit tests for Globals scoring state |
| `portal/components/GameFrame.tsx` | Modified | Add sign_in_request postMessage handler |
| `portal/app/profile/page.tsx` | New | User profile — points + per-mode streaks |
| `portal/app/admin/scoring/page.tsx` | New | Admin scoring page (server component) |
| `portal/app/admin/scoring/ScoringDashboard.tsx` | New | Admin scoring client component |

---

## Task 1: DB Migration

**Files:**
- Create: `supabase/migrations/007_membership_scoring.sql`

- [ ] Create the file with this exact content:

```sql
-- 007_membership_scoring.sql

-- Rebrand
UPDATE public.games SET name = '#HashAttack!' WHERE slug = 'tic-tac-toe';

-- member_points: denormalized balance
CREATE TABLE IF NOT EXISTS public.member_points (
  user_id      uuid PRIMARY KEY REFERENCES public.users ON DELETE CASCADE,
  total_points int NOT NULL DEFAULT 0,
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- point_transactions: immutable audit log
CREATE TABLE IF NOT EXISTS public.point_transactions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users ON DELETE CASCADE,
  game_id    uuid NOT NULL REFERENCES public.games ON DELETE CASCADE,
  game_mode  text NOT NULL DEFAULT 'classic',
  source     text NOT NULL CHECK (source IN ('ai_win', 'online_win', 'bonus')),
  amount     int NOT NULL,
  streak_at  int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- consecutive_wins: per user × game × mode
CREATE TABLE IF NOT EXISTS public.consecutive_wins (
  user_id        uuid REFERENCES public.users ON DELETE CASCADE,
  game_id        uuid REFERENCES public.games ON DELETE CASCADE,
  game_mode      text NOT NULL DEFAULT 'classic',
  current_streak int NOT NULL DEFAULT 0,
  best_streak    int NOT NULL DEFAULT 0,
  last_win_at    timestamptz,
  PRIMARY KEY (user_id, game_id, game_mode)
);

-- point_tiers: admin-configured, no seeds
-- NULL game_id/game_mode = global fallback
CREATE TABLE IF NOT EXISTS public.point_tiers (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id    uuid REFERENCES public.games ON DELETE CASCADE,
  game_mode  text,
  min_streak int NOT NULL,
  max_streak int,
  multiplier numeric(5,2) NOT NULL,
  UNIQUE (game_id, game_mode, min_streak)
);

-- game_mode_stars: base value per game × mode
CREATE TABLE IF NOT EXISTS public.game_mode_stars (
  game_id    uuid REFERENCES public.games ON DELETE CASCADE,
  game_mode  text NOT NULL DEFAULT 'classic',
  base_stars int NOT NULL DEFAULT 1,
  PRIMARY KEY (game_id, game_mode)
);

-- Seed: classic = 1 star
INSERT INTO public.game_mode_stars (game_id, game_mode, base_stars)
SELECT id, 'classic', 1 FROM public.games WHERE slug = 'tic-tac-toe'
ON CONFLICT DO NOTHING;

-- event_multipliers: time-gated bonus (UI in Sprint 2)
CREATE TABLE IF NOT EXISTS public.event_multipliers (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id  uuid REFERENCES public.seasons ON DELETE CASCADE,
  game_id    uuid,
  game_mode  text,
  multiplier numeric(5,2) NOT NULL DEFAULT 1.0,
  starts_at  timestamptz NOT NULL,
  ends_at    timestamptz NOT NULL
);

-- RLS
ALTER TABLE public.member_points      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consecutive_wins   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_tiers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_mode_stars    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_multipliers  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users read own points"       ON public.member_points      FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users read own transactions" ON public.point_transactions  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users read own streaks"      ON public.consecutive_wins    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "public read tiers"           ON public.point_tiers         FOR SELECT USING (true);
CREATE POLICY "public read mode stars"      ON public.game_mode_stars     FOR SELECT USING (true);
CREATE POLICY "public read event mults"     ON public.event_multipliers   FOR SELECT USING (true);

-- Admin policies (reuse pattern from migration 005)
CREATE POLICY "admins manage tiers" ON public.point_tiers FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins manage mode stars" ON public.game_mode_stars FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins manage event mults" ON public.event_multipliers FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins read all points" ON public.member_points FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins read all transactions" ON public.point_transactions FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins read all streaks" ON public.consecutive_wins FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));

-- RPC: award_win_points
CREATE OR REPLACE FUNCTION public.award_win_points(
  p_user_id   uuid,
  p_game_id   uuid,
  p_game_mode text,
  p_source    text DEFAULT 'ai_win'
) RETURNS int LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_streak     int;
  v_base_stars int;
  v_multiplier numeric;
  v_event_mult numeric;
  v_pts        int;
BEGIN
  INSERT INTO public.consecutive_wins (user_id, game_id, game_mode, current_streak, best_streak, last_win_at)
  VALUES (p_user_id, p_game_id, p_game_mode, 1, 1, now())
  ON CONFLICT (user_id, game_id, game_mode) DO UPDATE
    SET current_streak = consecutive_wins.current_streak + 1,
        best_streak    = GREATEST(consecutive_wins.best_streak, consecutive_wins.current_streak + 1),
        last_win_at    = now()
  RETURNING current_streak INTO v_streak;

  SELECT COALESCE((SELECT base_stars FROM public.game_mode_stars
    WHERE game_id = p_game_id AND game_mode = p_game_mode), 1) INTO v_base_stars;

  SELECT multiplier INTO v_multiplier FROM public.point_tiers
  WHERE (game_id = p_game_id OR game_id IS NULL)
    AND (game_mode = p_game_mode OR game_mode IS NULL)
    AND min_streak <= v_streak
    AND (max_streak IS NULL OR max_streak >= v_streak)
  ORDER BY (game_id IS NOT NULL)::int DESC, (game_mode IS NOT NULL)::int DESC, min_streak DESC
  LIMIT 1;

  IF v_multiplier IS NULL THEN RETURN 0; END IF;

  SELECT COALESCE((SELECT multiplier FROM public.event_multipliers
    WHERE now() BETWEEN starts_at AND ends_at
      AND (game_id = p_game_id OR game_id IS NULL)
      AND (game_mode = p_game_mode OR game_mode IS NULL)
    ORDER BY (game_id IS NOT NULL)::int DESC, (game_mode IS NOT NULL)::int DESC
    LIMIT 1), 1.0) INTO v_event_mult;

  v_pts := ROUND(v_base_stars * v_multiplier * v_event_mult)::int;

  INSERT INTO public.point_transactions (user_id, game_id, game_mode, source, amount, streak_at)
  VALUES (p_user_id, p_game_id, p_game_mode, p_source, v_pts, v_streak);

  INSERT INTO public.member_points (user_id, total_points, updated_at) VALUES (p_user_id, v_pts, now())
  ON CONFLICT (user_id) DO UPDATE
    SET total_points = member_points.total_points + v_pts, updated_at = now();

  RETURN v_pts;
END;
$$;

-- RPC: reset_win_streak
CREATE OR REPLACE FUNCTION public.reset_win_streak(
  p_user_id uuid, p_game_id uuid, p_game_mode text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.consecutive_wins SET current_streak = 0
  WHERE user_id = p_user_id AND game_id = p_game_id AND game_mode = p_game_mode;
END;
$$;
```

- [ ] Apply to Supabase: Dashboard → SQL Editor → paste → Run.
  Expected: green success, no errors.

- [ ] Verify in Table Editor: 6 new tables present. `game_mode_stars` has 1 row (classic/1★). `games` row for tic-tac-toe shows `name = '#HashAttack!'`.

- [ ] Commit:
```bash
git add supabase/migrations/007_membership_scoring.sql
git commit -m "feat: membership scoring schema, RPCs, and #HashAttack! rebrand"
```

---

## Task 2: Globals.gd

**Files:**
- Modify: `games/tic-tac-toe/scripts/Globals.gd`

- [ ] Replace entire file:

```gdscript
extends Node

const GAME_SLUG := "tic-tac-toe"

signal auth_ready

var supabase: SupabaseClient

var current_user: Dictionary = {}
# When signed in: { id: String, username: String, points: int }
# Empty when signed out.

var current_game_id: String = ""
var current_game_mode: String = "classic"
var current_streak: Dictionary = {}
# Keys = game_mode strings, values = int current streak count.

var jwt: String = "":
	set(value):
		jwt = value
		supabase.set_jwt(value)

func _ready() -> void:
	supabase = SupabaseClient.new()
	supabase.init(
		ProjectSettings.get_setting("supabase/url"),
		ProjectSettings.get_setting("supabase/anon_key")
	)
	add_child(supabase)

func is_signed_in() -> bool:
	return not current_user.is_empty()
```

- [ ] Commit:
```bash
git add games/tic-tac-toe/scripts/Globals.gd
git commit -m "feat: auth state vars and is_signed_in() in Globals"
```

---

## Task 3: SupabaseClient.gd — async methods

**Files:**
- Modify: `games/tic-tac-toe/scripts/SupabaseClient.gd`

- [ ] Append these methods at the end of the file (before nothing — just paste after the last `}` of `_drain_ws`):

```gdscript
# ── Async helpers ─────────────────────────────────────────────────────────────
# Each spawns a disposable HTTPRequest, awaits request_completed, frees itself.
# Returns [status_code: int, body: Variant].

func _async_get(path: String, bearer_override: String = "") -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	var hdrs: PackedStringArray
	if bearer_override != "":
		hdrs = PackedStringArray(["apikey: " + _anon_key, "Authorization: Bearer " + bearer_override])
	else:
		hdrs = _headers()
	http.request(_url + path, hdrs, HTTPClient.METHOD_GET)
	var raw: Array = await http.request_completed
	http.queue_free()
	var body: Variant = null
	var bytes := raw[3] as PackedByteArray
	if bytes.size() > 0:
		body = JSON.parse_string(bytes.get_string_from_utf8())
	return [raw[1], body]

func _async_post(path: String, payload: Dictionary) -> Array:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(_url + path,
		_headers(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	var raw: Array = await http.request_completed
	http.queue_free()
	var body: Variant = null
	var bytes := raw[3] as PackedByteArray
	if bytes.size() > 0:
		body = JSON.parse_string(bytes.get_string_from_utf8())
	return [raw[1], body]

# ── Public async API ──────────────────────────────────────────────────────────

func validate_session(token: String) -> Dictionary:
	# Returns {id, username} from public.users, or {} on failure.
	var auth_raw: Array = await _async_get("/auth/v1/user", token)
	if auth_raw[0] != 200 or not auth_raw[1] is Dictionary:
		return {}
	var uid: String = auth_raw[1].get("id", "")
	if uid.is_empty():
		return {}
	var profile_raw: Array = await _async_get("/rest/v1/users?id=eq.%s&select=username" % uid)
	if profile_raw[0] != 200 or not profile_raw[1] is Array or profile_raw[1].is_empty():
		return {}
	return {"id": uid, "username": profile_raw[1][0].get("username", "")}

func fetch_game_id(slug: String) -> String:
	var raw: Array = await _async_get("/rest/v1/games?slug=eq.%s&select=id" % slug)
	if raw[0] != 200 or not raw[1] is Array or raw[1].is_empty():
		return ""
	return raw[1][0].get("id", "")

func get_member_points(user_id: String) -> int:
	var raw: Array = await _async_get(
		"/rest/v1/member_points?user_id=eq.%s&select=total_points" % user_id)
	if raw[0] != 200 or not raw[1] is Array or raw[1].is_empty():
		return 0
	return int(raw[1][0].get("total_points", 0))

func get_current_streak(user_id: String, game_id: String, game_mode: String) -> int:
	var raw: Array = await _async_get(
		"/rest/v1/consecutive_wins?user_id=eq.%s&game_id=eq.%s&game_mode=eq.%s&select=current_streak"
		% [user_id, game_id, game_mode])
	if raw[0] != 200 or not raw[1] is Array or raw[1].is_empty():
		return 0
	return int(raw[1][0].get("current_streak", 0))

func call_rpc(fn_name: String, params: Dictionary) -> Variant:
	# Returns parsed body (200/204) or null on failure.
	var raw: Array = await _async_post("/rest/v1/rpc/" + fn_name, params)
	if raw[0] in [200, 204]:
		return raw[1]
	push_warning("SupabaseClient.call_rpc %s → %d" % [fn_name, raw[0]])
	return null

func get_leaderboard(game_id: String, limit: int = 20) -> Array:
	# Requires member_points→users FK recognized by PostgREST.
	var raw: Array = await _async_get(
		"/rest/v1/member_points?select=total_points,users(username)&order=total_points.desc&limit=%d" % limit)
	if raw[0] == 200 and raw[1] is Array:
		return raw[1]
	return []
```

- [ ] Commit:
```bash
git add games/tic-tac-toe/scripts/SupabaseClient.gd
git commit -m "feat: async REST helpers and RPC/auth methods in SupabaseClient"
```

---

## Task 4: PortalBridge.gd — auth → Globals

**Files:**
- Modify: `games/tic-tac-toe/scripts/PortalBridge.gd`

- [ ] Replace entire file:

```gdscript
class_name PortalBridge
extends Node

signal auth_token_received(token: String)

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			window.__godotMsg = '';
			window.addEventListener('message', function(e) {
				if (e.data && e.data.type) {
					window.__godotMsg = JSON.stringify(e.data);
				}
			});
		""")

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var raw: String = JavaScriptBridge.eval("window.__godotMsg || ''")
	if raw == "":
		return
	JavaScriptBridge.eval("window.__godotMsg = ''")
	var msg = JSON.parse_string(raw)
	if msg == null:
		return
	match msg.get("type", ""):
		"auth_token":
			var token: String = msg.get("token", "")
			auth_token_received.emit(token)
			if not token.is_empty() and not Globals.is_signed_in():
				_populate_auth(token)

func _populate_auth(token: String) -> void:
	Globals.jwt = token
	var profile: Dictionary = await Globals.supabase.validate_session(token)
	if profile.is_empty():
		return
	Globals.current_user = {
		"id":       profile.get("id", ""),
		"username": profile.get("username", ""),
		"points":   0
	}
	if Globals.current_game_id.is_empty():
		Globals.current_game_id = await Globals.supabase.fetch_game_id(Globals.GAME_SLUG)
	if not Globals.current_game_id.is_empty():
		Globals.current_user["points"] = await Globals.supabase.get_member_points(
			Globals.current_user["id"])
		Globals.current_streak["classic"] = await Globals.supabase.get_current_streak(
			Globals.current_user["id"], Globals.current_game_id, "classic")
	Globals.auth_ready.emit()

func send_game_ready() -> void:
	_post({"type": "game_ready"})

func send_match_end(winner: String, mode: String, score: int) -> void:
	_post({"type": "match_end", "winner": winner, "mode": mode, "score": score})

func request_auth() -> void:
	_post({"type": "auth_request"})

func send_sign_in_request() -> void:
	_post({"type": "sign_in_request"})

func _post(data: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage(%s, '*')" % JSON.stringify(data))
```

- [ ] Commit:
```bash
git add games/tic-tac-toe/scripts/PortalBridge.gd
git commit -m "feat: PortalBridge validates auth token and populates Globals"
```

---

## Task 5: Godot editor — MainMenu.tscn nodes

**Files:**
- Modify: `games/tic-tac-toe/scenes/MainMenu.tscn` (Godot editor)

Open `MainMenu.tscn` in Godot. Add these nodes (exact names matter — code references them):

- [ ] Add `Node` as direct child of root `Control`, script = `res://scripts/PortalBridge.gd`, name = `Bridge`

- [ ] In `VBoxContainer`, add `HBoxContainer` named `ProfileRow` (insert above `BtnVsAI`):
  - Child `Label` named `LblProfileIcon` (text empty, set via code)
  - Child `Label` named `LblUsername` (text empty)
  - Child `Label` named `LblPoints` (text empty)
  - Set `ProfileRow.visible = false`

- [ ] In `VBoxContainer`, add `Button` named `BtnSignIn` (below ProfileRow, above BtnVsAI):
  - Text = `SIGN IN`
  - `visible = false`

- [ ] In `VBoxContainer`, add `Button` named `BtnLeaderboard` (below BtnOnline):
  - Text empty (set via code)
  - `visible = false`

- [ ] Find the title `Label` (likely named `LblTitle`). Set its text to `#HashAttack!`.

- [ ] Save scene.

---

## Task 6: MainMenu.gd

**Files:**
- Modify: `games/tic-tac-toe/scenes/MainMenu.gd`

- [ ] Replace entire file:

```gdscript
extends Control

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	$VBoxContainer/BtnVsAI.pressed.connect(_on_vs_ai)
	$VBoxContainer/BtnLocal.pressed.connect(_on_local)
	$VBoxContainer/BtnOnline.pressed.connect(_on_online)
	$VBoxContainer/BtnSignIn.pressed.connect(_on_sign_in)
	$VBoxContainer/BtnLeaderboard.pressed.connect(_on_leaderboard)

	$VBoxContainer/ProfileRow/LblProfileIcon.text = FA6.icon("fa-user")
	$VBoxContainer/BtnLeaderboard.text = FA6.icon("fa-trophy") + "  LEADERBOARD"

	$Bridge.send_game_ready()
	$Bridge.auth_token_received.connect(func(_t): pass)  # auth via Globals.auth_ready

	if not Globals.auth_ready.is_connected(_refresh_auth_ui):
		Globals.auth_ready.connect(_refresh_auth_ui)

	_refresh_auth_ui()

func _refresh_auth_ui() -> void:
	var signed_in := Globals.is_signed_in()
	$VBoxContainer/ProfileRow.visible = signed_in
	$VBoxContainer/BtnLeaderboard.visible = signed_in
	$VBoxContainer/BtnSignIn.visible = not signed_in
	if signed_in:
		$VBoxContainer/ProfileRow/LblUsername.text = Globals.current_user.get("username", "")
		$VBoxContainer/ProfileRow/LblPoints.text = "★ %d" % Globals.current_user.get("points", 0)

func _on_sign_in() -> void:
	SFX.click()
	$Bridge.send_sign_in_request()

func _on_leaderboard() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/LeaderboardScene.tscn")

func _on_vs_ai() -> void:
	SFX.click()
	Globals.current_game_mode = "classic"
	get_tree().change_scene_to_file("res://scenes/AIDifficultySelect.tscn")

func _on_local() -> void:
	SFX.click()
	Globals.current_game_mode = "classic"
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_local()
	get_tree().root.add_child(board)
	queue_free()

func _on_online() -> void:
	SFX.click()
	Globals.current_game_mode = "classic"
	get_tree().change_scene_to_file("res://scenes/OnlineLobby.tscn")
```

- [ ] Run in editor (non-web). MainMenu loads, no crash. SIGN IN button visible.

- [ ] Commit:
```bash
git add games/tic-tac-toe/scenes/MainMenu.gd
git commit -m "feat: auth-aware MainMenu with profile row and leaderboard button"
```

---

## Task 7: Godot editor — GameBoard.tscn streak badge

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameBoard.tscn` (Godot editor)

- [ ] Open `GameBoard.tscn`. Find `VBoxContainer`. Add `HBoxContainer` named `StreakBadge` as the first child (above `LblStatus`):
  - Child `Label` named `LblStreakIcon`, text = `🔥`
  - Child `Label` named `LblStreakCount`, text = `0`
  - Align to top-right: set `size_flags_horizontal = SHRINK_END` on `StreakBadge`, or wrap in a `HBoxContainer` row with a spacer.

- [ ] Save scene.

---

## Task 8: GameBoard.gd — streak badge + RPC win flow

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameBoard.gd`

- [ ] Add instance variable after existing vars:
```gdscript
var _pts_awarded: int = 0
```

- [ ] Add these three methods anywhere before `_on_game_over`:

```gdscript
func _update_streak_badge() -> void:
	if not has_node("VBoxContainer/StreakBadge"):
		return
	if not Globals.is_signed_in():
		$VBoxContainer/StreakBadge.visible = false
		return
	$VBoxContainer/StreakBadge.visible = true
	var streak: int = Globals.current_streak.get(Globals.current_game_mode, 0)
	$VBoxContainer/StreakBadge/LblStreakCount.text = str(streak)
	var col: Color
	if streak >= 20:
		col = Color("#ff2d95")
	elif streak >= 10:
		col = Color("#a855f7")
	elif streak >= 5:
		col = Color("#00d4ff")
	else:
		col = Color(0.55, 0.55, 0.55, 0.8)
	$VBoxContainer/StreakBadge/LblStreakIcon.add_theme_color_override("font_color", col)
	$VBoxContainer/StreakBadge/LblStreakCount.add_theme_color_override("font_color", col)

func _award_points_if_signed_in(source: String) -> void:
	if not Globals.is_signed_in() or Globals.current_game_id.is_empty():
		return
	var result: Variant = await Globals.supabase.call_rpc("award_win_points", {
		"p_user_id":   Globals.current_user["id"],
		"p_game_id":   Globals.current_game_id,
		"p_game_mode": Globals.current_game_mode,
		"p_source":    source
	})
	_pts_awarded = int(result) if result != null else 0
	Globals.current_user["points"] = Globals.current_user.get("points", 0) + _pts_awarded
	Globals.current_streak[Globals.current_game_mode] = \
		Globals.current_streak.get(Globals.current_game_mode, 0) + 1
	_update_streak_badge()
	if _pts_awarded > 0:
		_show_pts_popup(_pts_awarded)

func _show_pts_popup(pts: int) -> void:
	var lbl := Label.new()
	lbl.text = "+%d ★" % pts
	lbl.add_theme_color_override("font_color", Color("#00d4ff"))
	lbl.position = Vector2(size.x / 2.0 - 50, size.y / 2.0 - 40)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.06)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(lbl.queue_free)
```

- [ ] In `_ready()`, after `_refresh_ui()`, add:
```gdscript
	_update_streak_badge()
```

- [ ] Replace the final block of `_on_game_over()` — find:
```gdscript
	_highlight_win_line()
	var game_over = load("res://scenes/GameOver.tscn").instantiate()
	game_over.setup(winner, _score_x, _score_o, _mode, self)
	get_tree().root.add_child(game_over)
```
Replace with:
```gdscript
	_highlight_win_line()

	var local_won := false
	var rpc_source := "ai_win"
	match _mode:
		Mode.VS_AI:
			local_won = (_state.result == GameState.GameResult.X_WINS)
			rpc_source = "ai_win"
		Mode.ONLINE:
			local_won = (
				(_player_mark == GameState.Player.X and _state.result == GameState.GameResult.X_WINS) or
				(_player_mark == GameState.Player.O and _state.result == GameState.GameResult.O_WINS))
			rpc_source = "online_win"
		Mode.LOCAL:
			local_won = false  # local 2P excluded from scoring

	_pts_awarded = 0
	if local_won:
		await _award_points_if_signed_in(rpc_source)
	elif _state.result != GameState.GameResult.DRAW and _mode != Mode.LOCAL:
		if Globals.is_signed_in() and not Globals.current_game_id.is_empty():
			Globals.current_streak[Globals.current_game_mode] = 0
			_update_streak_badge()
			Globals.supabase.call_rpc("reset_win_streak", {
				"p_user_id":   Globals.current_user["id"],
				"p_game_id":   Globals.current_game_id,
				"p_game_mode": Globals.current_game_mode
			})

	var game_over = load("res://scenes/GameOver.tscn").instantiate()
	game_over.setup(winner, _score_x, _score_o, _mode, self,
		_pts_awarded, Globals.current_streak.get(Globals.current_game_mode, 0))
	get_tree().root.add_child(game_over)
```

- [ ] Test in editor: play vs AI, win. No crash. Signed out → no points awarded. Works as before.

- [ ] Commit:
```bash
git add games/tic-tac-toe/scenes/GameBoard.gd
git commit -m "feat: streak badge and win/loss RPC flow in GameBoard"
```

---

## Task 9: Godot editor — GameOver.tscn nodes

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameOver.tscn` (Godot editor)

- [ ] Open `GameOver.tscn`. In `VBoxContainer`, add above `LblResult`:
  - `Label` named `LblStreakDisplay`, text empty, `visible = false`
  - `Label` named `LblPtsEarned`, text empty, `visible = false`
  - `Panel` named `MilestoneBanner`, `visible = false`
    - Child `Label` named `LblMilestone`, text empty

- [ ] Save scene.

---

## Task 10: GameOver.gd — streak + pts + milestone

**Files:**
- Modify: `games/tic-tac-toe/scenes/GameOver.gd`

- [ ] Replace entire file:

```gdscript
extends Control

var _score_x: int
var _score_o: int
var _mode: GameBoard.Mode
var _board_ref: GameBoard

func setup(winner: String, score_x: int, score_o: int, mode: GameBoard.Mode,
		board: GameBoard, pts_awarded: int = 0, current_streak: int = 0) -> void:
	_score_x = score_x
	_score_o = score_o
	_mode = mode
	_board_ref = board

	match winner:
		"X":
			$VBoxContainer/LblResult.text = "X WINS!"
			$VBoxContainer/LblResult.add_theme_color_override("font_color", Color("#00d4ff"))
			$VBoxContainer/LblSub.text = "X wins the match"
		"O":
			$VBoxContainer/LblResult.text = "O WINS!"
			$VBoxContainer/LblResult.add_theme_color_override("font_color", Color("#a855f7"))
			$VBoxContainer/LblSub.text = "O wins the match"
		_:
			$VBoxContainer/LblResult.text = "DRAW"
			$VBoxContainer/LblResult.add_theme_color_override("font_color", Color("#94a3b8"))
			$VBoxContainer/LblSub.text = "No winner this time"

	if Globals.is_signed_in() and pts_awarded > 0:
		$VBoxContainer/LblPtsEarned.visible = true
		$VBoxContainer/LblPtsEarned.text = "+%d ★" % pts_awarded
		$VBoxContainer/LblPtsEarned.add_theme_color_override("font_color", Color("#00d4ff"))

	if Globals.is_signed_in() and current_streak > 0:
		$VBoxContainer/LblStreakDisplay.visible = true
		$VBoxContainer/LblStreakDisplay.text = "🔥 %d STREAK" % current_streak

	if current_streak in [10, 20, 50]:
		$VBoxContainer/MilestoneBanner.visible = true
		$VBoxContainer/MilestoneBanner/LblMilestone.text = \
			"STREAK MASTER — %d WIN STREAK!" % current_streak
		$VBoxContainer/MilestoneBanner/LblMilestone.add_theme_color_override(
			"font_color", Color("#ff2d95"))

func _ready() -> void:
	$VBoxContainer/BtnRow/BtnPlayAgain.pressed.connect(_on_play_again)
	$VBoxContainer/BtnRow/BtnMenu.pressed.connect(_on_menu)
	if $VBoxContainer/LblResult.text != "DRAW":
		_shake()

func _shake() -> void:
	var origin = position
	var tween = create_tween()
	for i in 6:
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		tween.tween_property(self, "position", origin + offset, 0.04)
	tween.tween_property(self, "position", origin, 0.04)

func _on_play_again() -> void:
	SFX.click()
	_board_ref._game_over_fired = false
	_board_ref._state = GameState.new()
	_board_ref._refresh_ui()
	queue_free()

func _on_menu() -> void:
	SFX.click()
	_board_ref.queue_free()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	queue_free()
```

- [ ] Commit:
```bash
git add games/tic-tac-toe/scenes/GameOver.gd
git commit -m "feat: streak display and milestone banner on GameOver"
```

---

## Task 11: LeaderboardScene

**Files:**
- Create: `games/tic-tac-toe/scenes/LeaderboardScene.gd`
- Create: `games/tic-tac-toe/scenes/LeaderboardScene.tscn` (Godot editor)

- [ ] Create `LeaderboardScene.gd`:

```gdscript
extends Control

func _ready() -> void:
	var bg = load("res://scripts/BackgroundLayer.gd").new()
	add_child(bg)
	move_child(bg, 1)

	$VBoxContainer/BtnBack.pressed.connect(_on_back)
	$VBoxContainer/BtnBack.text = FA6.icon("fa-arrow-left") + "  BACK"
	$VBoxContainer/LblTitle.text = "LEADERBOARD"
	_load_leaderboard()

func _load_leaderboard() -> void:
	$VBoxContainer/LblLoading.visible = true
	$VBoxContainer/LblLoading.text = "LOADING..."
	$VBoxContainer/LeaderList.visible = false

	var game_id := Globals.current_game_id
	if game_id.is_empty():
		game_id = await Globals.supabase.fetch_game_id(Globals.GAME_SLUG)

	var rows: Array = await Globals.supabase.get_leaderboard(game_id, 20)

	$VBoxContainer/LblLoading.visible = false
	$VBoxContainer/LeaderList.visible = true

	for child in $VBoxContainer/LeaderList.get_children():
		child.queue_free()

	if rows.is_empty():
		var lbl := Label.new()
		lbl.text = "No scores yet. Be first!"
		$VBoxContainer/LeaderList.add_child(lbl)
		return

	for i in rows.size():
		var pts: int = int(rows[i].get("total_points", 0))
		var uname: String = rows[i].get("users", {}).get("username", "???")

		var entry := HBoxContainer.new()
		var rank  := Label.new()
		var name  := Label.new()
		var score := Label.new()

		rank.text  = "#%d" % (i + 1)
		rank.custom_minimum_size = Vector2(56, 0)
		name.text  = uname
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score.text = "★ %d" % pts

		if i < 3:
			var cyan := Color("#00d4ff")
			rank.add_theme_color_override("font_color", cyan)
			name.add_theme_color_override("font_color", cyan)
			score.add_theme_color_override("font_color", cyan)

		entry.add_child(rank)
		entry.add_child(name)
		entry.add_child(score)
		$VBoxContainer/LeaderList.add_child(entry)

func _on_back() -> void:
	SFX.click()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
```

- [ ] In Godot editor, create `LeaderboardScene.tscn`:
  - Root: `Control` with script `res://scenes/LeaderboardScene.gd`
  - Child `VBoxContainer`:
    - `Label` named `LblTitle`
    - `Label` named `LblLoading`
    - `VBoxContainer` named `LeaderList`
    - `Button` named `BtnBack`
  - Save scene.

- [ ] Commit:
```bash
git add games/tic-tac-toe/scenes/LeaderboardScene.gd
git commit -m "feat: LeaderboardScene — top 20 by total points"
```

---

## Task 12: GUT tests

**Files:**
- Create: `games/tic-tac-toe/tests/test_scoring.gd`

- [ ] Create file:

```gdscript
extends GutTest

func before_each() -> void:
	Globals.current_user = {}
	Globals.current_game_id = ""
	Globals.current_streak = {}
	Globals.current_game_mode = "classic"

func test_signed_out_when_user_empty() -> void:
	assert_false(Globals.is_signed_in())

func test_signed_in_when_user_populated() -> void:
	Globals.current_user = {"id": "abc", "username": "p1", "points": 0}
	assert_true(Globals.is_signed_in())

func test_streak_increments() -> void:
	Globals.current_streak["classic"] = 4
	Globals.current_streak["classic"] += 1
	assert_eq(Globals.current_streak["classic"], 5)

func test_streak_resets_on_loss() -> void:
	Globals.current_streak["classic"] = 7
	Globals.current_streak["classic"] = 0
	assert_eq(Globals.current_streak["classic"], 0)

func test_modes_independent() -> void:
	Globals.current_streak["classic"] = 5
	Globals.current_streak["ultimate"] = 3
	Globals.current_streak["classic"] = 0
	assert_eq(Globals.current_streak["classic"], 0)
	assert_eq(Globals.current_streak["ultimate"], 3)

func test_points_accumulate() -> void:
	Globals.current_user = {"id": "x", "username": "p", "points": 10}
	Globals.current_user["points"] += 5
	assert_eq(Globals.current_user["points"], 15)
```

- [ ] Run tests:
```powershell
cd games/tic-tac-toe
& "C:\Program Files\Godot 4\godot.windows.console.x86_64.exe" --headless -s addons/gut/gut_cmdln.gd
```
Expected: 6 tests pass.

- [ ] Commit:
```bash
git add games/tic-tac-toe/tests/test_scoring.gd
git commit -m "test: GUT unit tests for Globals scoring state"
```

---

## Task 13: Portal — GameFrame.tsx sign_in_request

**Files:**
- Modify: `portal/components/GameFrame.tsx`

- [ ] Add `useRouter` import and handler. Replace the `useEffect` deps array line and add the handler inside the `onGameMessage` callback. Full updated file:

```typescript
'use client'

import { useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { sendToGame, onGameMessage } from '@/lib/bridge'
import { createClient } from '@/lib/supabase/browser'

interface GameFrameProps {
  slug: string
  gameName: string
  matchId?: string
}

export function GameFrame({ slug, gameName, matchId }: GameFrameProps) {
  const iframeRef = useRef<HTMLIFrameElement>(null)
  const router = useRouter()

  useEffect(() => {
    const supabase = createClient()
    const cleanup = onGameMessage(async (msg) => {
      if (!iframeRef.current) return
      if (msg.type === 'game_ready' || msg.type === 'auth_request') {
        const { data: { session } } = await supabase.auth.getSession()
        if (session?.access_token) {
          sendToGame(iframeRef.current, 'auth_token', { token: session.access_token }, window.location.origin)
        }
      }
      if (msg.type === 'sign_in_request') {
        router.push('/login?return_to=' + encodeURIComponent(window.location.pathname))
      }
      if (msg.type === 'match_end') {
        await fetch('/api/scores', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ slug, score: msg.score, winner: msg.winner, mode: msg.mode }),
        })
      }
    }, window.location.origin)
    return cleanup
  }, [slug, router])

  const src = matchId
    ? `/games/${slug}/index.html?match=${matchId}`
    : `/games/${slug}/index.html`

  return (
    <div className="w-full h-full flex flex-col">
      <div className="font-pixel text-sm tracking-wide py-2 px-4 text-center border-b flex items-center justify-between"
           style={{
             background: 'rgba(10,10,26,0.96)',
             color: 'var(--text-secondary)',
             borderColor: 'var(--border-dim)',
             boxShadow: '0 2px 12px rgba(0,0,0,0.4)',
           }}>
        <span className="text-xs" style={{ color: 'var(--text-muted)' }}>NEXUS ARCADE</span>
        <span className="font-semibold" style={{ color: 'var(--neon-cyan)' }}>▶ {gameName.toUpperCase()}</span>
        <span className="text-xs font-semibold" style={{ color: 'var(--neon-green)' }}>● LIVE</span>
      </div>
      <iframe
        ref={iframeRef}
        src={src}
        className="w-full flex-1 border-0"
        allow="fullscreen"
        title={gameName}
      />
    </div>
  )
}
```

- [ ] `cd portal && npm run build` — no TypeScript errors.

- [ ] Commit:
```bash
git add portal/components/GameFrame.tsx
git commit -m "feat: handle sign_in_request postMessage from Godot iframe"
```

---

## Task 14: Portal — Profile page

**Files:**
- Create: `portal/app/profile/page.tsx`

- [ ] Create file:

```typescript
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function ProfilePage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login?return_to=/profile')

  const [pointsRes, streaksRes, txRes] = await Promise.all([
    supabase.from('member_points').select('total_points').eq('user_id', user.id).single(),
    supabase.from('consecutive_wins')
      .select('game_id, game_mode, best_streak, games(name)')
      .eq('user_id', user.id),
    supabase.from('point_transactions')
      .select('id, game_mode, source, amount, created_at, games(name)')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(10),
  ])

  const totalPoints = pointsRes.data?.total_points ?? 0
  const streaks     = streaksRes.data ?? []
  const transactions = txRes.data ?? []

  return (
    <div className="min-h-screen p-6" style={{ background: 'var(--bg-deep)', color: 'var(--text-primary)' }}>
      <h1 className="font-pixel text-3xl mb-8" style={{ color: 'var(--neon-cyan)' }}>PROFILE</h1>

      <section className="mb-8 p-4 rounded-lg border" style={{ borderColor: 'var(--border-dim)', background: 'var(--bg-card)' }}>
        <p className="text-xs mb-1" style={{ color: 'var(--text-muted)' }}>TOTAL STARS</p>
        <p className="font-pixel text-4xl" style={{ color: 'var(--neon-cyan)' }}>★ {totalPoints}</p>
      </section>

      {streaks.length > 0 && (
        <section className="mb-8">
          <h2 className="font-pixel text-sm mb-3" style={{ color: 'var(--text-secondary)' }}>BEST STREAKS</h2>
          <div className="grid gap-2">
            {(streaks as any[]).map((s) => (
              <div key={`${s.game_id}-${s.game_mode}`}
                   className="flex justify-between p-3 rounded border"
                   style={{ borderColor: 'var(--border-dim)', background: 'var(--bg-card)' }}>
                <span className="text-sm font-semibold">
                  {s.games?.name ?? '—'} · {(s.game_mode as string).toUpperCase()}
                </span>
                <span style={{ color: 'var(--neon-cyan)' }}>🔥 {s.best_streak}</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {transactions.length > 0 && (
        <section>
          <h2 className="font-pixel text-sm mb-3" style={{ color: 'var(--text-secondary)' }}>RECENT AWARDS</h2>
          <div className="grid gap-2">
            {(transactions as any[]).map((t) => (
              <div key={t.id}
                   className="flex justify-between items-center p-3 rounded border"
                   style={{ borderColor: 'var(--border-dim)', background: 'var(--bg-card)' }}>
                <div>
                  <span className="text-sm font-semibold">{t.games?.name ?? '—'}</span>
                  <span className="text-xs ml-2" style={{ color: 'var(--text-muted)' }}>
                    {t.game_mode} · {(t.source as string).replace('_', ' ')}
                  </span>
                </div>
                <span className="font-pixel text-sm" style={{ color: 'var(--neon-cyan)' }}>+{t.amount} ★</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {streaks.length === 0 && transactions.length === 0 && (
        <p style={{ color: 'var(--text-muted)' }}>No activity yet. Win a match to earn your first stars!</p>
      )}
    </div>
  )
}
```

- [ ] `npm run build` — no errors.

- [ ] Commit:
```bash
git add portal/app/profile/page.tsx
git commit -m "feat: profile page with total points and streak history"
```

---

## Task 15: Portal — Admin scoring page

**Files:**
- Create: `portal/app/admin/scoring/page.tsx`
- Create: `portal/app/admin/scoring/ScoringDashboard.tsx`

- [ ] Create `portal/app/admin/scoring/page.tsx`:

```typescript
import { isPlatformAdmin } from '@/lib/data/admin'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { ScoringDashboard } from './ScoringDashboard'

export default async function AdminScoringPage() {
  const isAdmin = await isPlatformAdmin()
  if (!isAdmin) redirect('/login')

  const supabase = createClient()
  const [starsRes, tiersRes, gamesRes] = await Promise.all([
    supabase.from('game_mode_stars').select('*, games(name)').order('game_id'),
    supabase.from('point_tiers').select('*, games(name)').order('min_streak'),
    supabase.from('games').select('id, name, slug').order('name'),
  ])

  return (
    <ScoringDashboard
      initialStars={starsRes.data ?? []}
      initialTiers={tiersRes.data ?? []}
      games={gamesRes.data ?? []}
    />
  )
}
```

- [ ] Create `portal/app/admin/scoring/ScoringDashboard.tsx`:

```typescript
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/browser'

interface Game    { id: string; name: string; slug: string }
interface StarRow { game_id: string; game_mode: string; base_stars: number; games?: { name: string } }
interface TierRow { id: string; game_id: string | null; game_mode: string | null; min_streak: number; max_streak: number | null; multiplier: number; games?: { name: string } }

interface Props {
  initialStars: StarRow[]
  initialTiers: TierRow[]
  games: Game[]
}

export function ScoringDashboard({ initialStars, initialTiers, games }: Props) {
  const [stars, setStars]   = useState<StarRow[]>(initialStars)
  const [tiers, setTiers]   = useState<TierRow[]>(initialTiers)
  const [status, setStatus] = useState('')
  const supabase = createClient()

  async function saveStars(row: StarRow, n: number) {
    setStatus('Saving...')
    await supabase.from('game_mode_stars')
      .upsert({ game_id: row.game_id, game_mode: row.game_mode, base_stars: n })
    setStars(p => p.map(r =>
      r.game_id === row.game_id && r.game_mode === row.game_mode ? { ...r, base_stars: n } : r))
    setStatus('Saved.')
  }

  async function addStars(gameId: string, mode: string, n: number) {
    setStatus('Adding...')
    const { data } = await supabase.from('game_mode_stars')
      .upsert({ game_id: gameId, game_mode: mode, base_stars: n })
      .select('*, games(name)').single()
    if (data) setStars(p => [...p, data as StarRow])
    setStatus('Added.')
  }

  async function deleteTier(id: string) {
    setStatus('Deleting...')
    await supabase.from('point_tiers').delete().eq('id', id)
    setTiers(p => p.filter(t => t.id !== id))
    setStatus('Deleted.')
  }

  async function addTier(gameId: string | null, mode: string | null, min: number, max: number | null, mult: number) {
    setStatus('Adding...')
    const { data } = await supabase.from('point_tiers')
      .insert({ game_id: gameId, game_mode: mode, min_streak: min, max_streak: max, multiplier: mult })
      .select('*, games(name)').single()
    if (data) setTiers(p => [...p, data as TierRow])
    setStatus('Added.')
  }

  const inputCls = "bg-transparent border rounded px-2 py-1 text-sm"
  const inputStyle = { borderColor: 'var(--border-dim)' }
  const btnPrimary = { background: 'var(--neon-cyan)', color: '#000' }
  const btnDanger  = { background: 'var(--neon-magenta)', color: '#000' }

  return (
    <div className="p-6 min-h-screen" style={{ background: 'var(--bg-deep)', color: 'var(--text-primary)' }}>
      <h1 className="font-pixel text-2xl mb-2" style={{ color: 'var(--neon-cyan)' }}>SCORING CONFIG</h1>
      {status && <p className="text-sm mb-4" style={{ color: 'var(--neon-cyan)' }}>{status}</p>}

      {/* Mode Stars */}
      <section className="mb-10">
        <h2 className="font-pixel text-base mb-3">MODE STARS</h2>
        <table className="w-full text-sm mb-4">
          <thead><tr style={{ color: 'var(--text-muted)' }}>
            <th className="text-left p-2">Game</th><th className="text-left p-2">Mode</th>
            <th className="text-left p-2">Stars</th><th className="text-left p-2" />
          </tr></thead>
          <tbody>
            {stars.map(row => {
              const [val, setVal] = useState(row.base_stars)  // eslint-disable-line
              return (
                <tr key={`${row.game_id}-${row.game_mode}`} className="border-b" style={{ borderColor: 'var(--border-dim)' }}>
                  <td className="p-2">{row.games?.name ?? row.game_id}</td>
                  <td className="p-2">{row.game_mode}</td>
                  <td className="p-2">
                    <input type="number" min={1} value={val}
                      onChange={e => setVal(Number(e.target.value))}
                      className={`w-16 ${inputCls}`} style={inputStyle} />
                  </td>
                  <td className="p-2">
                    <button onClick={() => saveStars(row, val)}
                      className="text-xs px-2 py-1 rounded" style={btnPrimary}>Save</button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        <AddStarsForm games={games} onAdd={addStars} />
      </section>

      {/* Tiers */}
      <section>
        <h2 className="font-pixel text-base mb-2">STREAK MULTIPLIER TIERS</h2>
        {tiers.length === 0 && (
          <div className="mb-4 p-3 border rounded text-sm"
               style={{ borderColor: 'var(--neon-magenta)', color: 'var(--neon-magenta)' }}>
            ⚠ No tiers configured — wins award 0 points until tiers are added.
          </div>
        )}
        <table className="w-full text-sm mb-4">
          <thead><tr style={{ color: 'var(--text-muted)' }}>
            <th className="text-left p-2">Game</th><th className="text-left p-2">Mode</th>
            <th className="text-left p-2">Min</th><th className="text-left p-2">Max</th>
            <th className="text-left p-2">Mult</th><th className="text-left p-2" />
          </tr></thead>
          <tbody>
            {tiers.map(t => (
              <tr key={t.id} className="border-b" style={{ borderColor: 'var(--border-dim)' }}>
                <td className="p-2">{t.games?.name ?? 'All'}</td>
                <td className="p-2">{t.game_mode ?? 'All'}</td>
                <td className="p-2">{t.min_streak}</td>
                <td className="p-2">{t.max_streak ?? '∞'}</td>
                <td className="p-2">{t.multiplier}×</td>
                <td className="p-2">
                  <button onClick={() => deleteTier(t.id)}
                    className="text-xs px-2 py-1 rounded" style={btnDanger}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <AddTierForm games={games} onAdd={addTier} />
      </section>
    </div>
  )
}

function AddStarsForm({ games, onAdd }: { games: Game[]; onAdd: (g: string, m: string, n: number) => void }) {
  const [gameId, setGameId] = useState(games[0]?.id ?? '')
  const [mode,   setMode]   = useState('classic')
  const [stars,  setStars]  = useState(1)
  const cls = "bg-transparent border rounded px-2 py-1 text-sm"
  const sty = { borderColor: 'var(--border-dim)' }
  return (
    <div className="flex gap-2 flex-wrap items-center">
      <select value={gameId} onChange={e => setGameId(e.target.value)} className={cls} style={sty}>
        {games.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
      </select>
      <input value={mode} onChange={e => setMode(e.target.value)} placeholder="mode"
        className={`w-28 ${cls}`} style={sty} />
      <input type="number" min={1} value={stars} onChange={e => setStars(Number(e.target.value))}
        className={`w-16 ${cls}`} style={sty} />
      <button onClick={() => onAdd(gameId, mode, stars)}
        className="text-sm px-3 py-1 rounded" style={{ background: 'var(--neon-cyan)', color: '#000' }}>
        + Add
      </button>
    </div>
  )
}

function AddTierForm({ games, onAdd }: { games: Game[]; onAdd: (g: string|null, m: string|null, min: number, max: number|null, mult: number) => void }) {
  const [gameId, setGameId] = useState('')
  const [mode,   setMode]   = useState('')
  const [min,    setMin]    = useState(1)
  const [max,    setMax]    = useState('')
  const [mult,   setMult]   = useState(1)
  const cls = "bg-transparent border rounded px-2 py-1 text-sm"
  const sty = { borderColor: 'var(--border-dim)' }
  return (
    <div className="flex gap-2 flex-wrap items-center">
      <select value={gameId} onChange={e => setGameId(e.target.value)} className={cls} style={sty}>
        <option value="">All games</option>
        {games.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
      </select>
      <input value={mode} onChange={e => setMode(e.target.value)} placeholder="mode (blank=all)"
        className={`w-32 ${cls}`} style={sty} />
      <input type="number" min={1} value={min} onChange={e => setMin(Number(e.target.value))} placeholder="min"
        className={`w-16 ${cls}`} style={sty} />
      <input type="number" value={max} onChange={e => setMax(e.target.value)} placeholder="max"
        className={`w-20 ${cls}`} style={sty} />
      <input type="number" step="0.01" min={0.01} value={mult} onChange={e => setMult(Number(e.target.value))}
        className={`w-16 ${cls}`} style={sty} />
      <button onClick={() => onAdd(gameId||null, mode||null, min, max?Number(max):null, mult)}
        className="text-sm px-3 py-1 rounded" style={{ background: 'var(--neon-cyan)', color: '#000' }}>
        + Add Tier
      </button>
    </div>
  )
}
```

- [ ] `npm run build` — no TypeScript errors.

- [ ] Commit:
```bash
git add portal/app/admin/scoring/
git commit -m "feat: admin scoring page — mode stars and tier CRUD"
```

---

## Task 16: Web export

- [ ] Export from Godot:
```powershell
cd games/tic-tac-toe
& "C:\Program Files\Godot 4\godot.windows.console.x86_64.exe" --headless --export-release "Web" "../../portal/public/games/tic-tac-toe/index.html"
```
Expected: no errors, files updated in `portal/public/games/tic-tac-toe/`.

- [ ] Commit:
```bash
git add portal/public/games/tic-tac-toe/
git commit -m "build: re-export #HashAttack! web build"
```

---

## Task 17: Admin — configure tiers (manual)

Do this in your Railway deployment or on `npm run dev` portal.

- [ ] Sign in as admin → navigate to `/admin/scoring`
- [ ] Verify `#HashAttack! / classic / 1★` row present in Mode Stars
- [ ] Add three tier rows (leave game and mode blank = global):

| Min | Max | Multiplier |
|-----|-----|-----------|
| 1 | 4 | 1.00 |
| 5 | 20 | 5.00 |
| 21 | (blank) | 20.00 |

- [ ] Verify warning banner disappears after first tier is saved.

---

## Task 18: Smoke test (manual, web build)

- [ ] `cd portal && npm run dev` → open `http://localhost:3000/games/tic-tac-toe`
- [ ] Game title bar shows `#HASHATTACK!`
- [ ] Signed-out: SIGN IN button visible in Godot MainMenu. Press → redirected to portal login.
- [ ] Sign in → return to game → profile row shows username + ★ points
- [ ] Win vs AI → `+X ★` popup → GameOver shows streak + pts earned
- [ ] Check `/profile` → total stars incremented, transaction visible
- [ ] Win 5 times in a row → streak badge turns cyan + glow
- [ ] Lose → streak badge resets to dim 0
- [ ] Press LEADERBOARD in MainMenu → scene loads, shows table (or "No scores yet" if first player)
- [ ] Check `/admin/scoring` → tier table shows 3 rows, no warning banner

---

## Self-Review Against Spec

| Spec requirement | Task |
|-----------------|------|
| Rebrand `#HashAttack!` — DB, Godot, portal | Task 1, 5, 6, 16 |
| Agent names (Gladys/Dex/Uma/Mary/Tessa) | Done pre-plan (committed) |
| `member_points`, `point_transactions` | Task 1 |
| `consecutive_wins` per game mode | Task 1 |
| `point_tiers`, `game_mode_stars`, `event_multipliers` | Task 1 |
| `award_win_points` RPC (base_stars × tier × event mult) | Task 1 |
| `reset_win_streak` RPC | Task 1 |
| No default tier seeds, admin warning | Task 1, 15 |
| Globals: current_user, current_streak, current_game_mode | Task 2 |
| SupabaseClient async methods | Task 3 |
| PortalBridge: token → validate → Globals | Task 4 |
| MainMenu: profile row / SIGN IN button | Task 5, 6 |
| MainMenu: LEADERBOARD button | Task 5, 6 |
| Streak badge always visible in GameBoard | Task 7, 8 |
| Badge glow tiers (dim/cyan/purple/magenta) | Task 8 |
| Win → RPC → +X★ popup | Task 8 |
| Loss → reset streak RPC | Task 8 |
| GameOver: streak display + pts + milestone banner | Task 9, 10 |
| LeaderboardScene top-20 | Task 11 |
| GUT tests | Task 12 |
| Portal: sign_in_request handler | Task 13 |
| Portal: profile page | Task 14 |
| Portal: admin scoring CRUD | Task 15 |
| Tier A values (1-4=1×, 5-20=5×, >20=20×) | Task 17 |
| Scoring: AI + online only (not local 2P) | Task 8 |
| Tessa test checklist | Task 18 |
