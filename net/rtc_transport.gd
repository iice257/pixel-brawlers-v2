class_name RtcTransport
extends NetTransport
## WebRTC data channel between two browsers (the web export; desktop would need the webrtc-native extension).
## Rooms are set up through a SignalChannel (HTTP relay or Supabase Realtime): the host reserves a code, the guest says hello, the host sends an offer,
## the guest answers, both trade ICE candidates, and the signalling channel is not used again. The data channel is unordered and unreliable, like UDP.

const STUN := ["stun:stun.l.google.com:19302"]
const HELLO_EVERY := 1.2

var sig: SignalChannel
var is_host := false
var code := ""
var status := "idle"                 # idle | reserving | waiting | negotiating | open | failed
var _pc: WebRTCPeerConnection
var _ch: WebRTCDataChannel
var _remote_set := false
var _ice_wait: Array = []
var _hello_t := 0.0
var _hello_ms := 0
var _ice_out := 0                    # candidates we found / the other side sent, for the status readout
var _ice_in := 0
var _sdp_out := false
var _sdp_in := false

static func available() -> bool:
	return OS.has_feature("web")

func _init(channel: SignalChannel) -> void:
	sig = channel

## Host: reserve a room; `code` is set once the signalling channel answers.
func host() -> void:
	is_host = true; status = "reserving"
	sig.open_room()

## Guest: join a room by its code.
func join(room: String) -> void:
	is_host = false; code = room.to_upper(); status = "negotiating"
	sig.join_room(code)
	if _make_peer(): sig.send({ "t": "hello" })

func _make_peer() -> bool:
	_pc = WebRTCPeerConnection.new()
	var err := _pc.initialize({ "iceServers": [{ "urls": STUN }] })
	if err != OK:
		error = "WebRTC is not available on this platform"; status = "failed"; return false
	_pc.session_description_created.connect(func(type: String, sdp: String):
		_pc.set_local_description(type, sdp); _sdp_out = true
		sig.send({ "t": "sdp", "type": type, "sdp": sdp }))
	_pc.ice_candidate_created.connect(func(media: String, index: int, cname: String): _ice_out += 1; sig.send({ "t": "ice", "media": media, "index": index, "name": cname }))
	_ch = _pc.create_data_channel("g", { "negotiated": true, "id": 1, "ordered": false, "maxRetransmits": 0 })
	return true

func _on_signal(m: Dictionary) -> void:
	match m.get("t", ""):
		"hello":
			if is_host and _pc == null:
				status = "negotiating"
				if _make_peer(): _pc.create_offer()
		"sdp":
			if _pc == null: return
			_pc.set_remote_description(String(m.type), String(m.sdp)); _sdp_in = true
			_remote_set = true
			for c in _ice_wait: _pc.add_ice_candidate(c[0], c[1], c[2])
			_ice_wait.clear()
		"ice":
			if _pc == null: return
			_ice_in += 1
			if _remote_set: _pc.add_ice_candidate(String(m.media), int(m.index), String(m.name))
			else: _ice_wait.append([String(m.media), int(m.index), String(m.name)])

func _raw_poll() -> void:
	if status == "idle" or status == "failed": return
	if not connected:
		sig.poll()
		if sig.status == "failed": error = sig.error; status = "failed"; return
		if is_host and code == "" and sig.code != "": code = sig.code; status = "waiting"
		for m in sig.take(): _on_signal(m)
		if not is_host and not _remote_set and sig.status == "ready":     # the first hello can land before the host is listening: repeat it until the offer arrives
			var now := Time.get_ticks_msec()
			_hello_t += 0.0 if _hello_ms == 0 else float(now - _hello_ms) / 1000.0
			_hello_ms = now
			if _hello_t >= HELLO_EVERY: _hello_t = 0.0; sig.send({ "t": "hello" })
	if _pc == null: return
	_pc.poll()
	if _ch != null and _ch.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		if not connected:
			connected = true; status = "open"
			sig.close()
		while _ch.get_available_packet_count() > 0: _in.append(_ch.get_packet())
	elif connected and _ch != null and _ch.get_ready_state() == WebRTCDataChannel.STATE_CLOSED:
		connected = false; error = "the connection closed"

## One line per connection stage, for the lobby readout: which stage broke shows up as the first line that is not OK.
func diag() -> Array:
	var sg := "OK" if sig.status == "ready" or connected else ("FAILED" if sig.status == "failed" else "CONNECTING")
	var out: Array = ["SIGNALLING  " + sg]
	if _pc == null:
		out.append("PEER  " + ("WAITING FOR A GUEST" if is_host else "STARTING"))
		return out
	out.append("SDP  SENT %s / GOT %s" % ["YES" if _sdp_out else "NO", "YES" if _sdp_in else "NO"])
	out.append("ICE GATHERING  %s  (%d FOUND, %d RECEIVED)" % [["NEW", "GATHERING", "COMPLETE"][clampi(int(_pc.get_gathering_state()), 0, 2)], _ice_out, _ice_in])
	out.append("ICE STATE  " + ["NEW", "CONNECTING", "CONNECTED", "DISCONNECTED", "FAILED", "CLOSED"][clampi(int(_pc.get_connection_state()), 0, 5)])
	out.append("DATA CHANNEL  " + ["CONNECTING", "OPEN", "CLOSING", "CLOSED"][clampi(int(_ch.get_ready_state()), 0, 3)] if _ch != null else "DATA CHANNEL  NONE")
	return out

## The first stage that has not completed, for failure messages.
func stuck_at() -> String:
	for l in diag():
		if not (l.ends_with("OK") or l.ends_with("OPEN") or l.ends_with("CONNECTED") or l.ends_with("COMPLETE") or l.contains("GOT YES")): return String(l)
	return ""

func _raw_send(b: PackedByteArray) -> void:
	if connected and _ch != null: _ch.put_packet(b)

func close() -> void:
	if _ch != null: _ch.close()
	if _pc != null: _pc.close()
	sig.close()
