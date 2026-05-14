extends Control

enum RestPhase { IDLE, FETCHING_ROOM, JOINING_ROOM }
var _rest_phase: RestPhase = RestPhase.IDLE
var _room_id: String = ""
var _room_code: String = ""
var _player_mark: GameState.Player = GameState.Player.X
var _portal_bridge: PortalBridge

func _ready() -> void:
	_portal_bridge = PortalBridge.new()
	add_child(_portal_bridge)
	_portal_bridge.auth_token_received.connect(_on_auth_token)

	$VBoxContainer/BtnCreate.pressed.connect(_on_create)
	$VBoxContainer/JoinRow/BtnJoin.pressed.connect(_on_join)
	$VBoxContainer/BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))

	Globals.supabase.rest_completed.connect(_on_rest)

	var url_code = RoomManager.get_room_code_from_url()
	if url_code != "":
		$VBoxContainer/JoinRow/InputCode.text = url_code
		_set_status("Room code detected. Sign in to join.")

	_portal_bridge.request_auth()

func _on_auth_token(token: String) -> void:
	Globals.jwt = token
	_set_status("Signed in. Create or join a room.")

func _on_create() -> void:
	if Globals.jwt == "":
		_portal_bridge.request_auth()
		_set_status("Waiting for sign-in...")
		return
	_set_status("Creating room...")
	_rest_phase = RestPhase.FETCHING_ROOM
	var user_id = _get_user_id_from_jwt(Globals.jwt)
	RoomManager.create_room(Globals.supabase, user_id)

func _on_join() -> void:
	if Globals.jwt == "":
		_portal_bridge.request_auth()
		_set_status("Waiting for sign-in...")
		return
	var code = $VBoxContainer/JoinRow/InputCode.text.strip_edges().to_upper()
	if code.length() != 6:
		_set_status("Enter a valid 6-character room code.")
		return
	_set_status("Looking up room...")
	_rest_phase = RestPhase.FETCHING_ROOM
	RoomManager.fetch_room(Globals.supabase, code)

func _on_rest(status: int, body: Variant) -> void:
	if _rest_phase == RestPhase.IDLE:
		return
	var phase = _rest_phase
	_rest_phase = RestPhase.IDLE

	if status < 200 or status >= 300:
		_set_status("Error %d. Try again." % status)
		return

	if phase == RestPhase.FETCHING_ROOM:
		var rows: Array = body if body is Array else [body]
		if rows.is_empty():
			_set_status("Room not found.")
			return
		var room: Dictionary = rows[0]
		_room_id = room.get("id", "")
		_room_code = room.get("room_code", "")

		if room.get("status") == "waiting" and room.get("host_id") == _get_user_id_from_jwt(Globals.jwt):
			_player_mark = GameState.Player.X
			_set_status("Room created! Share this link:")
			$VBoxContainer/LblShareUrl.text = RoomManager.get_share_url(_room_code)
			Globals.supabase.connect_realtime("room:" + _room_id)
			Globals.supabase.realtime_message.connect(_on_realtime)
		elif room.get("status") == "waiting":
			_player_mark = GameState.Player.O
			var user_id = _get_user_id_from_jwt(Globals.jwt)
			_rest_phase = RestPhase.JOINING_ROOM
			RoomManager.join_room(Globals.supabase, _room_id, user_id)
		else:
			_set_status("Room already full or finished.")

	elif phase == RestPhase.JOINING_ROOM:
		Globals.supabase.connect_realtime("room:" + _room_id)
		await get_tree().create_timer(0.6).timeout
		Globals.supabase.broadcast("room:" + _room_id, "guest_joined", {})
		_launch_game()

func _on_realtime(_channel: String, event: String, _payload: Dictionary) -> void:
	if event == "guest_joined":
		_launch_game()

func _launch_game() -> void:
	Globals.supabase.rest_completed.disconnect(_on_rest)
	var board = load("res://scenes/GameBoard.tscn").instantiate()
	board.setup_online(_room_id, _player_mark, Globals.supabase)
	get_tree().root.add_child(board)
	get_tree().current_scene = board
	queue_free()

func _exit_tree() -> void:
	if Globals.supabase.rest_completed.is_connected(_on_rest):
		Globals.supabase.rest_completed.disconnect(_on_rest)
	if Globals.supabase.realtime_message.is_connected(_on_realtime):
		Globals.supabase.realtime_message.disconnect(_on_realtime)

func _set_status(text: String) -> void:
	$VBoxContainer/LblStatus.text = text

func _get_user_id_from_jwt(jwt: String) -> String:
	var parts = jwt.split(".")
	if parts.size() < 2:
		return ""
	var padded = parts[1]
	while padded.length() % 4 != 0:
		padded += "="
	var decoded = Marshalls.base64_to_utf8(padded.replace("-", "+").replace("_", "/"))
	var payload = JSON.parse_string(decoded)
	return payload.get("sub", "") if payload else ""
