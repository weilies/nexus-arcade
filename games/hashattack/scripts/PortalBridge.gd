class_name PortalBridge
extends Node

signal auth_token_received(token: String)
signal not_in_browser(message_type: String)

var _poll_timer: Timer = null

func _ready() -> void:
	if not OS.has_feature("web"):
		return
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
			if token.is_empty():
				# Portal signalled sign-out
				if Globals.is_signed_in():
					clear_auth()
			elif not Globals.is_signed_in():
				_stop_poll()
				_populate_auth(token)

func _populate_auth(token: String) -> void:
	Globals.jwt = token
	var profile: Dictionary = await Globals.supabase.validate_session(token)
	if profile.is_empty():
		push_warning("[PortalBridge] validate_session returned empty")
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
	print("[PortalBridge] Auth populated: user=%s points=%d" % [
		Globals.current_user.get("username", "?"), Globals.current_user.get("points", 0)])
	Globals.auth_ready.emit()

func send_game_ready() -> void:
	_post({"type": "game_ready"})
	# Start polling: retry auth_request every 3s until signed in (max 10 tries).
	# Covers race where portal sent token before Godot JS listener was ready,
	# and cases where onAuthStateChange fires late (mobile, slow networks).
	_start_poll()

func _start_poll() -> void:
	if _poll_timer or not is_inside_tree():
		return
	var attempts := [0]
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 3.0
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(func():
		if Globals.is_signed_in() or attempts[0] >= 10:
			_stop_poll()
			return
		attempts[0] += 1
		request_auth()
	)
	add_child(_poll_timer)

func _stop_poll() -> void:
	if _poll_timer and is_instance_valid(_poll_timer):
		_poll_timer.stop()
		_poll_timer.queue_free()
	_poll_timer = null

func send_match_end(winner: String, mode: String, score: int) -> void:
	_post({"type": "match_end", "winner": winner, "mode": mode, "score": score})

func request_auth() -> void:
	_post({"type": "auth_request"})

func send_sign_in_request() -> void:
	_post({"type": "sign_in_request"})

func send_sign_out_request() -> void:
	_post({"type": "sign_out_request"})
	# Don't wait for portal confirm — optimistic local clear so UI responds instantly.
	# Portal will also fire onAuthStateChange → send empty token → clear_auth again (idempotent).
	clear_auth()

func clear_auth() -> void:
	Globals.jwt = ""
	Globals.current_user = {}
	Globals.current_game_id = ""
	Globals.current_streak = {}
	Globals.auth_ready.emit()

func _post(data: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage(%s, '*')" % JSON.stringify(data))
	else:
		var msg_type: String = data.get("type", "?")
		print("[PortalBridge] Skipped postMessage in non-web env: ", msg_type)
		not_in_browser.emit(msg_type)
