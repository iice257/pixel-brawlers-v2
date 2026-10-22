class_name NetTransport
extends RefCounted
## A datagram pipe to one peer. Subclasses move bytes (UDP, WebRTC data channel); this base adds a simulated one-way latency and packet loss for testing.
## poll() once a frame, send() whenever, take() returns what arrived.

var sim_latency_ms := 0
var sim_loss := 0.0
var connected := false        # a peer address / channel is known: packets can flow
var error := ""
var _out: Array = []          # [due_msec, bytes]
var _in: Array = []

func send(b: PackedByteArray) -> void:
	if sim_loss > 0.0 and randf() < sim_loss: return
	if sim_latency_ms <= 0: _raw_send(b)
	else: _out.append([Time.get_ticks_msec() + sim_latency_ms, b])

func poll() -> void:
	_raw_poll()
	if _out.is_empty(): return
	var now := Time.get_ticks_msec()
	while not _out.is_empty() and _out[0][0] <= now: _raw_send(_out.pop_front()[1])

func take() -> Array:
	var r := _in
	_in = []
	return r

func close() -> void:
	pass

func _raw_send(_b: PackedByteArray) -> void:
	pass

func _raw_poll() -> void:
	pass
