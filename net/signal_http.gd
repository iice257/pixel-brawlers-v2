class_name SignalHttp
extends SignalChannel
## Signalling through the small HTTP relay in tools/signal_server.py: the host reserves a 4-letter room, both sides poll for messages addressed to them.

const POLL_EVERY := 0.4

var base := ""
var _rq_get: HTTPRequest
var _rq_post: HTTPRequest
var _posting := false
var _post_q: Array = []
var _getting := false
var _since := 0
var _t := 0.0

func _init(url: String, host: bool) -> void:
	base = url.rstrip("/"); is_host = host
	var root := (Engine.get_main_loop() as SceneTree).root
	_rq_get = HTTPRequest.new(); _rq_post = HTTPRequest.new()
	root.add_child.call_deferred(_rq_get); root.add_child.call_deferred(_rq_post)

func open_room() -> void:
	status = "reserving"
	_rq_get.request_completed.connect(_on_new, CONNECT_ONE_SHOT)
	(func(): _rq_get.request(base + "/new")).call_deferred()

func join_room(room: String) -> void:
	code = room.to_upper(); status = "ready"

func _on_new(result: int, response: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var d = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response != 200 or not (d is Dictionary):
		error = "no connection to the signalling server"; status = "failed"; return
	code = String(d.code); status = "ready"

func send(m: Dictionary) -> void:
	_post_q.append(JSON.stringify(m))
	_pump_post()

func _pump_post() -> void:
	if _posting or _post_q.is_empty() or not _rq_post.is_inside_tree(): return
	_posting = true
	var to := "guest" if is_host else "host"
	if not _rq_post.request_completed.is_connected(_on_post): _rq_post.request_completed.connect(_on_post)
	_rq_post.request(base + "/r/" + code + "/" + to, PackedStringArray(["Content-Type: text/plain"]), HTTPClient.METHOD_POST, _post_q.pop_front())

func _on_post(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_posting = false
	_pump_post()

func poll() -> void:
	if status != "ready" or code == "": return
	_pump_post()
	if not _rq_get.request_completed.is_connected(_on_get): _rq_get.request_completed.connect(_on_get)
	_t -= 1.0 / 60.0
	if _t <= 0.0 and not _getting and _rq_get.is_inside_tree():
		_t = POLL_EVERY; _getting = true
		_rq_get.request(base + "/r/" + code + "/" + ("host" if is_host else "guest") + "?since=" + str(_since))

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
		if m is Dictionary: inbox.append(m)

func close() -> void:
	for n in [_rq_get, _rq_post]:
		if is_instance_valid(n): n.queue_free()
