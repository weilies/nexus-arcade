class_name RoomManager
extends RefCounted

const GAME_SLUG = "hashattack"
const ROOM_CODE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const MIN_PASSWORD_LEN = 4

static var last_error: String = ""

static func generate_room_code() -> String:
	var code = ""
	for i in 6:
		code += ROOM_CODE_CHARS[randi() % ROOM_CODE_CHARS.length()]
	return code

static func get_share_url(room_code: String) -> String:
	if OS.has_feature("web"):
		var base = JavaScriptBridge.eval("window.location.origin + window.location.pathname")
		return "%s?room=%s" % [base, room_code]
	return "http://localhost:3000/games/hashattack?room=" + room_code

static func get_room_code_from_url() -> String:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('room') || ''"
		)
	return ""

# ── Async API (returns Dictionary / Array) ────────────────────────────────────

# Returns the created row, or {} on failure.
static func timer_label_from_seconds(secs: int) -> String:
	match secs:
		3: return "BLITZ"
		6: return "CASUAL"
		9: return "CHILL"
		_: return "OFF"

static func timer_seconds_from_label(lbl: String) -> int:
	match lbl:
		"BLITZ": return 3
		"CASUAL": return 6
		"CHILL": return 9
		_: return 0

static func create_room_async(sb: SupabaseClient, host_id: String,
		room_name: String, is_private: bool, password: String,
		game_mode: String, timer_label: String) -> Dictionary:
	var payload := {
		"game_slug": GAME_SLUG,
		"room_code": generate_room_code(),
		"host_id": host_id,
		"room_name": room_name,
		"is_private": is_private,
		"game_mode": game_mode,
		"timer_label": timer_label,
		"status": "waiting",
		"state": {"board": ["","","","","","","","",""], "turn": "X", "winner": ""}
	}
	if is_private:
		payload["password"] = password
	last_error = ""
	var raw: Array = await sb._async_post_pref("/rest/v1/game_rooms?select=*", payload)
	if raw[0] < 200 or raw[0] >= 300:
		last_error = "HTTP %d: %s" % [raw[0], str(raw[1])]
		push_warning("[RoomManager] create_room failed " + last_error)
		print("[RoomManager] create_room failed ", last_error)
		return {}
	if raw[1] is Array and not raw[1].is_empty():
		return raw[1][0]
	if raw[1] is Dictionary:
		return raw[1]
	return {}

# Returns array of joinable rooms (status=waiting AND no guest yet, newest first).
static func list_waiting_rooms_async(sb: SupabaseClient, limit: int = 10, offset: int = 0) -> Array:
	var path := "/rest/v1/game_rooms?game_slug=eq.%s&status=eq.waiting&guest_id=is.null&select=id,room_code,room_name,is_private,host_id,game_mode,timer_label,created_at&order=created_at.desc&limit=%d&offset=%d" % [GAME_SLUG, limit, offset]
	var raw: Array = await sb._async_get(path)
	if raw[0] == 200 and raw[1] is Array:
		return raw[1]
	return []

# Fetch a single room (for password check + join). Returns {} if not found.
static func fetch_room_by_id_async(sb: SupabaseClient, room_id: String) -> Dictionary:
	var raw: Array = await sb._async_get(
		"/rest/v1/game_rooms?id=eq.%s&select=*" % room_id)
	if raw[0] == 200 and raw[1] is Array and not raw[1].is_empty():
		return raw[1][0]
	return {}

static func fetch_room_by_code_async(sb: SupabaseClient, room_code: String) -> Dictionary:
	var raw: Array = await sb._async_get(
		"/rest/v1/game_rooms?room_code=eq.%s&game_slug=eq.%s&select=*" % [room_code, GAME_SLUG])
	if raw[0] == 200 and raw[1] is Array and not raw[1].is_empty():
		return raw[1][0]
	return {}

# Returns true on successful join (200..299).
static func join_room_async(sb: SupabaseClient, room_id: String, guest_id: String) -> bool:
	var http := HTTPRequest.new()
	http.accept_gzip = false
	sb.add_child(http)
	var hdrs: PackedStringArray = sb._headers(["Content-Type: application/json", "Prefer: return=representation"])
	var body := JSON.stringify({"guest_id": guest_id, "status": "active"})
	http.request(sb._url + "/rest/v1/game_rooms?id=eq." + room_id,
		hdrs, HTTPClient.METHOD_PATCH, body)
	var raw: Array = await http.request_completed
	http.queue_free()
	return raw[1] >= 200 and raw[1] < 300
