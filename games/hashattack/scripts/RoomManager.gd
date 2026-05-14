class_name RoomManager
extends RefCounted

const GAME_SLUG = "hashattack"
const ROOM_CODE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

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

static func create_room(sb: SupabaseClient, host_id: String) -> void:
	var code = generate_room_code()
	sb.insert_row("game_rooms", {
		"game_slug": GAME_SLUG,
		"room_code": code,
		"host_id": host_id,
		"status": "waiting",
		"state": {"board": ["","","","","","","","",""], "turn": "X", "winner": ""}
	})

static func fetch_room(sb: SupabaseClient, room_code: String) -> void:
	sb.get_rows("game_rooms",
		"room_code=eq.%s&game_slug=eq.%s&select=*" % [room_code, GAME_SLUG])

static func join_room(sb: SupabaseClient, room_id: String, guest_id: String) -> void:
	sb.patch_row("game_rooms", "id=eq." + room_id,
		{"guest_id": guest_id, "status": "active"})
