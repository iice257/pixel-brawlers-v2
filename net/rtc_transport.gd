class_name RtcTransport
extends NetTransport
## WebRTC data channel between two browsers (the web export; desktop would need the webrtc-native extension).
## Rooms are set up through the signalling relay (tools/signal_server.py): the host reserves a 4-letter code, the guest says hello, the host
## sends an offer, the guest answers, both trade ICE candidates, and the relay is not used again. The channel is unordered and unreliable, like UDP.

const STUN := ["stun:stun.l.google.com:19302"]
const POLL_EVERY := 0.4

var is_host := false
var code := ""
var base := ""                       # signalling relay base URL, no trailing slash
var status := "idle"                 # idle | reserving | waiting | negotiating | open | failed
var _pc: WebRTCPeerConnection
var _ch: WebRTCDataChannel
var _get: HTTPRequest
var _post: HTTPRequest
var _posting := false
var _post_q: Array = []
var _getting := false
var _since := 0
var _t := 0.0
var _remote_set := false
var _ice_wait: Array = []
var _hello_t := 0.0

static func available() -> bool:
	return OS.has_feature("web")

func _init(signal_url: String) -> void:
	base = signal_url.rstrip("/")
	var root := (Engine.get_main_loop() as SceneTree).root
	_get = HTTPRequest.new(); _post = HTTPRequest.new()
	root.add_child.call_deferred(_get); root.add_child.call_deferred(_post)

## Host: reserve a room; `code` is set once the relay answers.
func host() -> void:
	is_host = true; status = "reserving"
	_get.request_completed.connect(_on_new, CONNECT_ONE_SHOT)
	_request_new.call_deferred()

func _request_new() -> void:
	_get.request(base + "/new")

## Guest: join a room by its code.
func join(room: String) -> void:
	is_host = false; code = room.to_upper(); status = "negotiating"
	if _make_peer():
		_get.request_completed.connect(_on_get)
		_signal({ "t": "hello" })

func _on_new(result: int, response: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var d = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response != 200 or not (d is Dictionary):
		error = "no connection to the signalling server"; status = "failed"; return
	code = String(d.code); status = "waiting"
	_get.request_completed.connect(_on_get)

func _make_peer() -> bool:
	_pc = WebRTCPeerConnection.new()
	var err := _pc.initialize({ "iceServers": [{ "urls": STUN }] })
	if err != OK:
		error = "WebRTC is not available on this platform"; status = "failed"; return false
	_pc.session_description_created.connect(func(type: String, sdp: String):
		_pc.set_local_description(type, sdp)
		_signal({ "t": "sdp", "type": type, "sdp": sdp }))
	_pc.ice_candidate_created.connect(func(media: String, index: int, cname: String): _signal({ "t": "ice", "media": media, "index": index, "name": cname }))
	_ch = _pc.create_data_channel("g", { "negotiated": true, "id": 1, "ordered": false, "maxRetransmits": 0 })
	return true

func _signal(m: Dictionary) -> void:
	_post_q.append(JSON.stringify(m))
	_pump_post()

func _pump_post() -> void:
	if _posting or _post_q.is_empty() or not _post.is_inside_tree(): return
	_posting = true
	var to := "guest" if is_host else "host"
	if not _post.request_completed.is_connected(_on_post): _post.request_completed.connect(_on_post)
	_post.request(base + "/r/" + code + "/" + to, PackedStringArray(["Content-Type: text/plain"]), HTTPClient.METHOD_POST, _post_q.pop_front())

func _on_post(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_posting = false
	_pump_post()

func _on_get(result: int, response: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_getting = false
	if result != HTTPRequest.RESULT_SUCCESS: return
	if response == 404:
		error = "room not found"; status = "failed"; return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if not (d is Dictionary): return
	_since = int(d.next)
	for raw in d.msgs:
		var m = JSON.parse_string(raw)
		if m is Dictionary: _on_signal(m)

func _on_signal(m: Dictionary) -> void:
	match m.get("t", ""):
		"hello":
			if is_host and _pc == null:
				status = "negotiating"
				if _make_peer(): _pc.create_offer()
		"sdp":
			if _pc == null: return
			_pc.set_remote_description(String(m.type), String(m.sdp))
			_remote_set = true
			for c in _ice_wait: _pc.add_ice_candidate(c[0], c[1], c[2])
			_ice_wait.clear()
		"ice":
			if _pc == null: return
			if _remote_set: _pc.add_ice_candidate(String(m.media), int(m.index), String(m.name))
			else: _ice_wait.append([String(m.media), int(m.index), String(m.name)])

func _raw_poll() -> void:
	if status == "idle" or status == "failed" or code == "": return
	_t -= 1.0 / 60.0
	if _t <= 0.0 and not _getting and _get.is_inside_tree() and not connected:
		_t = POLL_EVERY; _getting = true
		_get.request(base + "/r/" + code + "/" + ("host" if is_host else "guest") + "?since=" + str(_since))
		if not is_host and not _remote_set:                  # the first hello can land before the host is listening: repeat it until the offer arrives
			_hello_t += POLL_EVERY
			if _hello_t >= 1.2: _hello_t = 0.0; _signal({ "t": "hello" })
	if _pc == null: return
	_pc.poll()
	if _ch != null and _ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		if not connected:
			connected = true; status = "open"
		while _ch.get_available_packet_count() > 0: _in.append(_ch.get_packet())
	elif connected and _ch != null and _ch.get_ready_state() == WebRTCDataChannel.STATE_CLOSED:
		connected = false; error = "the connection closed"

func _raw_send(b: PackedByteArray) -> void:
	if connected and _ch != null: _ch.put_packet(b)

func close() -> void:
	if _ch != null: _ch.close()
	if _pc != null: _pc.close()
	for n in [_get, _post]:
		if is_instance_valid(n): n.queue_free()
