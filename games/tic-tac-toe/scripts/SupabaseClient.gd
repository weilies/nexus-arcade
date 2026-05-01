class_name SupabaseClient
extends Node

signal rest_completed(status_code: int, body: Variant)
signal realtime_message(channel: String, event: String, payload: Dictionary)

var _url: String
var _anon_key: String
var _jwt: String = ""

var _http: HTTPRequest
var _ws: WebSocketPeer = null
var _ws_ready: bool = false
var _ws_ref: int = 0
var _pending_channels: Array = []

func init(supabase_url: String, anon_key: String) -> void:
	_url = supabase_url.trim_suffix("/")
	_anon_key = anon_key

func set_jwt(jwt: String) -> void:
	_jwt = jwt

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_done)

func get_rows(table: String, query: String = "") -> void:
	var path = "/rest/v1/%s" % table
	if query != "":
		path += "?" + query
	_http.request(_url + path, _headers(), HTTPClient.METHOD_GET)

func insert_row(table: String, body: Dictionary) -> void:
	_http.request(_url + "/rest/v1/" + table,
		_headers(["Content-Type: application/json", "Prefer: return=representation"]),
		HTTPClient.METHOD_POST, JSON.stringify(body))

func patch_row(table: String, query: String, body: Dictionary) -> void:
	_http.request(_url + "/rest/v1/%s?%s" % [table, query],
		_headers(["Content-Type: application/json", "Prefer: return=representation"]),
		HTTPClient.METHOD_PATCH, JSON.stringify(body))

func _headers(extra: Array = []) -> PackedStringArray:
	var h = PackedStringArray()
	h.append("apikey: " + _anon_key)
	h.append("Authorization: Bearer " + (_jwt if _jwt != "" else _anon_key))
	for e in extra:
		h.append(e)
	return h

func _on_http_done(_result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = null
	if body.size() > 0:
		parsed = JSON.parse_string(body.get_string_from_utf8())
	rest_completed.emit(code, parsed)

func connect_realtime(channel_name: String) -> void:
	_pending_channels.append(channel_name)
	if _ws != null:
		return
	_ws = WebSocketPeer.new()
	var ws_url = _url.replace("https://", "wss://").replace("http://", "ws://")
	ws_url += "/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % _anon_key
	_ws.connect_to_url(ws_url)

func broadcast(channel_name: String, event: String, payload: Dictionary) -> void:
	if not _ws_ready:
		push_warning("SupabaseClient: not connected, cannot broadcast")
		return
	_ws_ref += 1
	var msg = {
		"topic": "realtime:" + channel_name,
		"event": "broadcast",
		"payload": {"type": "broadcast", "event": event, "payload": payload},
		"ref": str(_ws_ref)
	}
	_ws.send_text(JSON.stringify(msg))

func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _ws_ready:
				_ws_ready = true
				for ch in _pending_channels:
					_join_channel(ch)
				_pending_channels.clear()
			_drain_ws()
		WebSocketPeer.STATE_CLOSED:
			_ws_ready = false

func _join_channel(channel_name: String) -> void:
	_ws_ref += 1
	var payload: Dictionary = {
		"config": {
			"broadcast": {"ack": false, "self": false},
			"presence": {"key": ""}
		}
	}
	if _jwt != "":
		payload["access_token"] = _jwt
	var msg = {
		"topic": "realtime:" + channel_name,
		"event": "phx_join",
		"payload": payload,
		"ref": str(_ws_ref)
	}
	_ws.send_text(JSON.stringify(msg))

func _drain_ws() -> void:
	while _ws.get_available_packet_count() > 0:
		var text = _ws.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed == null:
			continue
		var event = parsed.get("event", "")
		if event == "broadcast":
			var topic = parsed.get("topic", "").replace("realtime:", "")
			var inner: Dictionary = parsed.get("payload", {})
			realtime_message.emit(topic, inner.get("event", ""), inner.get("payload", {}))
