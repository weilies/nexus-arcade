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
		push_warning("[PortalBridge] validate_session returned empty — user may be missing from public.users")
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
	print("[PortalBridge] Auth populated: user=%s, points=%d" % [Globals.current_user.get("username", "?"), Globals.current_user.get("points", 0)])
	Globals.auth_ready.emit()

func send_game_ready() -> void:
	_post({"type": "game_ready"})
	# If auth not received within 2s, re-request (handles race where portal
	# sent token before Godot JS listener was ready)
	get_tree().create_timer(2.0).timeout.connect(func():
		if not Globals.is_signed_in():
			request_auth()
	)

func send_match_end(winner: String, mode: String, score: int) -> void:
	_post({"type": "match_end", "winner": winner, "mode": mode, "score": score})

func request_auth() -> void:
	_post({"type": "auth_request"})

func send_sign_in_request() -> void:
	_post({"type": "sign_in_request"})

func send_sign_out_request() -> void:
	_post({"type": "sign_out_request"})

func clear_auth() -> void:
	Globals.jwt = ""
	Globals.current_user = {}
	Globals.current_game_id = ""
	Globals.current_streak = {}
	Globals.auth_ready.emit()

func _post(data: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage(%s, '*')" % JSON.stringify(data))
