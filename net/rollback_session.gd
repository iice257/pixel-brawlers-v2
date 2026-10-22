class_name RollbackSession
extends RefCounted
## Two-player rollback netcode over the deterministic MatchSim (GGPO style, transport agnostic).
## Each peer owns one fighter (`local`), samples its input DELAY frames ahead, predicts the remote input by repeating the last known one,
## and when the real input arrives and differs, restores the saved state and resimulates up to MAX_ROLLBACK frames.
## The driver calls advance(raw_local_input) once per 60 Hz tick, sends everything in `outbox`, and feeds received packets to receive().
## Desync detection: every SUM_EVERY frames each peer checksums the state of that frame (once all earlier inputs are confirmed) and sends it along.

const DELAY := 2
const MAX_ROLLBACK := 8
const SUM_EVERY := 10
const MAX_SEND := 60              # most input frames repeated in one packet (covers a lost packet)
const TIMEOUT_TICKS := 300        # five seconds without a packet from the peer
const PKT_INPUT := 1

var sim: MatchSim
var local := 0
var delay := DELAY
var max_rollback := MAX_ROLLBACK
var frame := 0                    # next frame to simulate
var outbox: Array = []            # PackedByteArray packets waiting to be sent
var events: Array = []            # fresh, de-duplicated sim events for the presenter (SFX, sparks)
var stalled := false
var desync := false
var desync_frame := -1
var rollbacks := 0                # resimulations so far (stats)
var max_depth := 0                # deepest rollback so far
var stall_frames := 0
var silent := 0                   # ticks since the last packet

var _inputs := [{}, {}]           # player -> frame -> packed input (local: sampled ahead; remote: received)
var _used := {}                   # frame -> [p0, p1] packed inputs the sim actually consumed
var _states := {}                 # frame -> state before stepping that frame
var _remote_known := -1           # highest frame such that every remote input up to it has arrived
var _peer_ack := -1               # highest frame of ours the peer has confirmed
var _rollback_to := -1
var _sampled := -1                # highest local frame sampled
var _sums := {}                   # frame -> our checksum
var _peer_sums := {}
var _recent_sums: Array = []      # [frame, sum] pairs repeated on outgoing packets
var _seen := {}                   # event dedupe keys

func _init(match_sim: MatchSim, local_player: int, input_delay := DELAY, max_rb := MAX_ROLLBACK) -> void:
	sim = match_sim; local = local_player; delay = input_delay; max_rollback = max_rb
	var n := pack(WorldSim.neutral())
	for f in delay: _inputs[local][f] = n          # nothing to press before the first sampled frame
	_sampled = delay - 1

static func pack(i: Dictionary) -> int:
	return (1 if i.get("left", false) else 0) | (2 if i.get("right", false) else 0) | (4 if i.get("up", false) else 0) | (8 if i.get("down", false) else 0) | (int(i.get("buttons", 0)) << 4)

static func unpack(v: int) -> Dictionary:
	return { "left": v & 1 != 0, "right": v & 2 != 0, "up": v & 4 != 0, "down": v & 8 != 0, "buttons": v >> 4 }

func remote() -> int:
	return 1 - local

## Frames we are ahead of the confirmed remote input (what a rollback could have to undo).
func prediction_depth() -> int:
	return frame - (_remote_known + 1)

func confirmed_frame() -> int:
	return _remote_known

## One 60 Hz tick: apply late remote inputs (rolling back if they differ from the prediction), then simulate the next frame.
func advance(raw_local: Dictionary) -> void:
	events.clear()
	silent += 1
	_check_sums()
	stalled = prediction_depth() >= max_rollback
	if stalled:
		stall_frames += 1
		_send()                          # still talk: the peer needs our inputs and acks to move on
		return
	var sample := frame + delay
	while _sampled < sample:
		_sampled += 1
		_inputs[local][_sampled] = pack(raw_local)
	if _rollback_to >= 0: _resimulate()
	_step_frame(true)
	_update_sums()
	_send()
	_prune()

func is_disconnected() -> bool:
	return silent > TIMEOUT_TICKS

# ---------------------------------------------------------------- simulation

func _predicted(p: int, f: int) -> int:
	if _inputs[p].has(f): return _inputs[p][f]
	return _inputs[p].get(_remote_known, pack(WorldSim.neutral())) if p == remote() else pack(WorldSim.neutral())

func _step_frame(fresh: bool) -> void:
	var pair := [0, 0]
	for p in 2: pair[p] = _predicted(p, frame)
	_states[frame] = sim.save()
	_used[frame] = pair
	sim.step([unpack(pair[0]), unpack(pair[1])])
	_collect_events(frame)
	frame += 1

func _resimulate() -> void:
	var target := frame
	var depth := target - _rollback_to
	frame = _rollback_to
	_rollback_to = -1
	sim.restore(_states[frame])
	rollbacks += 1
	max_depth = maxi(max_depth, depth)
	while frame < target: _step_frame(false)

func _collect_events(f: int) -> void:
	for e in sim.events:
		var key := "%d%s" % [f, var_to_str(e)]
		if _seen.has(key): continue
		_seen[key] = f
		events.append(e)

func _prune() -> void:
	var keep := frame - max_rollback - 4
	for f in _states.keys():
		if f < keep: _states.erase(f); _used.erase(f)
	for p in 2:
		for f in _inputs[p].keys():
			if f < keep - 40: _inputs[p].erase(f)
	for f in _sums.keys():
		if f < frame - 240: _sums.erase(f)
	if _seen.size() > 400:
		for k in _seen.keys():
			if _seen[k] < keep: _seen.erase(k)

# ---------------------------------------------------------------- checksums

func _update_sums() -> void:
	var f := _remote_known + 1 - (_remote_known + 1) % SUM_EVERY   # newest multiple of SUM_EVERY whose earlier inputs are all confirmed
	while f > 0 and not _sums.has(f):
		if _states.has(f) and _rollback_to < 0 and f <= _remote_known + 1 and f <= frame:
			var s := hash(var_to_str(_states[f])) & 0xFFFFFFFF
			_sums[f] = s
			_recent_sums.append([f, s])
			if _recent_sums.size() > 4: _recent_sums.pop_front()
		f -= SUM_EVERY
		if f < _remote_known - 3 * SUM_EVERY: break

func _check_sums() -> void:
	for f in _peer_sums.keys():
		if _sums.has(f):
			if _sums[f] != _peer_sums[f] and not desync:
				desync = true; desync_frame = f
			_peer_sums.erase(f)

# ---------------------------------------------------------------- wire

func _send() -> void:
	var from := maxi(_peer_ack + 1, _sampled - MAX_SEND + 1)
	var count := _sampled - from + 1
	if count <= 0: return
	var b := PackedByteArray()
	b.resize(1 + 4 + 1 + count * 2 + 4 + 1 + _recent_sums.size() * 8)
	var o := 0
	b.encode_u8(o, PKT_INPUT); o += 1
	b.encode_u32(o, from); o += 4
	b.encode_u8(o, count); o += 1
	for f in range(from, from + count):
		b.encode_u16(o, int(_inputs[local].get(f, 0))); o += 2
	b.encode_u32(o, _remote_known + 1); o += 4             # ack, offset by one so "nothing yet" is 0
	b.encode_u8(o, _recent_sums.size()); o += 1
	for ps in _recent_sums:
		b.encode_u32(o, ps[0]); o += 4
		b.encode_u32(o, ps[1]); o += 4
	outbox.append(b)

## Feed one packet from the peer.
func receive(b: PackedByteArray) -> void:
	if b.size() < 11 or b.decode_u8(0) != PKT_INPUT: return
	silent = 0
	var o := 1
	var from := b.decode_u32(o); o += 4
	var count := b.decode_u8(o); o += 1
	if b.size() < o + count * 2 + 5: return
	var r := remote()
	for k in count:
		var f := from + k
		var v := b.decode_u16(o); o += 2
		if f <= _remote_known or _inputs[r].has(f): continue
		_inputs[r][f] = v
		if f < frame and _used.has(f) and _used[f][r] != v:
			_rollback_to = f if _rollback_to < 0 else mini(_rollback_to, f)
	while _inputs[r].has(_remote_known + 1): _remote_known += 1
	var ack := b.decode_u32(o); o += 4
	if ack - 1 > _peer_ack: _peer_ack = ack - 1
	var n := b.decode_u8(o); o += 1
	for k in n:
		if b.size() < o + 8: break
		_peer_sums[b.decode_u32(o)] = b.decode_u32(o + 4); o += 8
