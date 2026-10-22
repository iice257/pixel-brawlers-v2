class_name NetLink
extends RefCounted
## One online match from first contact to the final tick: a NetTransport, the HELLO / START handshake that agrees on fighters, seed and stage,
## and the RollbackSession's packets. The host is player 1 (index 0), the guest player 2.
## HELLO (guest -> host, repeated) carries the guest's fighter; START (host -> guest, answered to every HELLO) carries the seed, both fighters and the stage.

const HELLO := 0x10
const START := 0x11
const HELLO_EVERY := 0.25

var transport: NetTransport
var is_host := true
var pick := "kestrel"
var stage := "stage1"
var state := "connecting"      # connecting | ready | failed
var info := {}                 # once ready: seed, fighters [p1, p2], stage
var session: RollbackSession
var _t := 0.0
var _pending: Array = []
var _guest_pick := ""

func _init(t: NetTransport, host: bool, my_pick: String, my_stage := "stage1") -> void:
	transport = t; is_host = host; pick = my_pick; stage = my_stage

func local_index() -> int:
	return 0 if is_host else 1

func peer_pick() -> String:
	return String(info.fighters[1 - local_index()]) if info.has("fighters") else ""

func poll(dt: float) -> void:
	transport.poll()
	if transport.error != "" and state != "ready": state = "failed"
	for p in transport.take(): _handle(p)
	if state == "connecting" and not is_host and transport.connected:
		_t -= dt
		if _t <= 0.0:
			_t = HELLO_EVERY
			transport.send(_msg(HELLO, { "pick": pick }))
	if session != null:
		for p in session.outbox: transport.send(p)
		session.outbox.clear()

func bind_session(s: RollbackSession) -> void:
	session = s
	for p in _pending: s.receive(p)
	_pending.clear()

func close() -> void:
	transport.close()

func _msg(kind: int, d: Dictionary) -> PackedByteArray:
	var b := PackedByteArray([kind])
	b.append_array(JSON.stringify(d).to_utf8_buffer())
	return b

func _handle(p: PackedByteArray) -> void:
	if p.is_empty(): return
	match p[0]:
		HELLO:
			if not is_host: return
			var d = JSON.parse_string(p.slice(1).get_string_from_utf8())
			if not (d is Dictionary): return
			_guest_pick = String(d.get("pick", "briggs"))
			if info.is_empty():
				info = { "seed": randi() % 1000000 + 1, "fighters": [pick, _guest_pick], "stage": stage }
			state = "ready"
			transport.send(_msg(START, info))
		START:
			if is_host: return
			var d = JSON.parse_string(p.slice(1).get_string_from_utf8())
			if not (d is Dictionary) or not d.has("fighters"): return
			info = d; state = "ready"
		RollbackSession.PKT_INPUT:
			if session != null: session.receive(p)
			else: _pending.append(p)
