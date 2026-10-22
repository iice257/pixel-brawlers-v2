class_name SignalSupabase
extends SignalChannel
## Signalling through a Supabase Realtime broadcast channel ("redline-<ROOM>"): no server code, the free tier is enough. Speaks the Phoenix channel
## protocol over a WebSocket: join the topic, send {event:"sig"} broadcasts, receive the other side's. Messages carry a "to" role so each side ignores its own echo.
## Config (data/net.json): { "signal_type": "supabase", "url": "https://<project>.supabase.co", "anon_key": "<anon public key>" }.

const HEARTBEAT := 25.0

var url := ""
var key := ""
var _ws := WebSocketPeer.new()
var _topic := ""
var _ref := 0
var _beat := HEARTBEAT
var _open := false
var _joined := false
var _q: Array = []
var _age := 0.0

func _init(project_url: String, anon_key: String, host: bool) -> void:
	url = project_url.rstrip("/"); key = anon_key; is_host = host

func open_room() -> void:
	status = "reserving"
	_start(RoomCode.random_room())

func join_room(room: String) -> void:
	status = "reserving"
	_start(room.to_upper())

func _start(room: String) -> void:
	code = room; _topic = "realtime:redline-" + room
	var ws_url := url.replace("https://", "wss://").replace("http://", "ws://") + "/realtime/v1/websocket?apikey=" + key + "&vsn=1.0.0"
	if _ws.connect_to_url(ws_url) != OK:
		error = "could not reach the signalling server"; status = "failed"

func _frame(topic: String, event: String, payload: Dictionary) -> void:
	_ref += 1
	_ws.send_text(JSON.stringify({ "topic": topic, "event": event, "payload": payload, "ref": str(_ref) }))

func send(m: Dictionary) -> void:
	var out := m.duplicate(); out["to"] = "guest" if is_host else "host"
	_q.append(out)
	_flush()

func _flush() -> void:
	if not _joined or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	for m in _q: _frame(_topic, "broadcast", { "type": "broadcast", "event": "sig", "payload": m })
	_q.clear()

func poll() -> void:
	_ws.poll()
	_age += 1.0 / 60.0
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _open:
				_open = true
				_frame(_topic, "phx_join", { "config": { "broadcast": { "self": false, "ack": false }, "presence": { "key": "" }, "private": false } })
			_beat -= 1.0 / 60.0
			if _beat <= 0.0:
				_beat = HEARTBEAT; _frame("phoenix", "heartbeat", {})
			while _ws.get_available_packet_count() > 0:
				_on_text(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if status != "failed":
				error = "the signalling connection closed"; status = "failed"
		_:
			if _age > 10.0 and not _open and status != "failed":
				error = "no connection to the signalling server"; status = "failed"

func _on_text(s: String) -> void:
	var d = JSON.parse_string(s)
	if not (d is Dictionary) or d.get("topic", "") != _topic: return
	match String(d.get("event", "")):
		"phx_reply":
			var p = d.get("payload", {})
			if p is Dictionary and p.get("status", "") == "ok" and not _joined:
				_joined = true; status = "ready"; _flush()
			elif p is Dictionary and p.get("status", "") == "error":
				error = "the signalling server refused the room"; status = "failed"
		"broadcast":
			var p = d.get("payload", {})
			if p is Dictionary and p.get("event", "") == "sig" and p.get("payload") is Dictionary:
				var m: Dictionary = p.payload
				if m.get("to", "") == ("host" if is_host else "guest"): inbox.append(m)
		"phx_error", "phx_close":
			error = "the signalling channel closed"; status = "failed"

func close() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN: _ws.close()
