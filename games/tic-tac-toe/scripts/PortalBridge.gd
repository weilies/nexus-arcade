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
			auth_token_received.emit(msg.get("token", ""))

func send_game_ready() -> void:
	_post({"type": "game_ready"})

func send_match_end(winner: String, mode: String, score: int) -> void:
	_post({"type": "match_end", "winner": winner, "mode": mode, "score": score})

func request_auth() -> void:
	_post({"type": "auth_request"})

func _post(data: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage(%s, '*')" % JSON.stringify(data))
