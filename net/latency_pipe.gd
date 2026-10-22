class_name LatencyPipe
extends RefCounted
## One direction of a simulated network: packets come out `delay` ticks later (plus jitter), some are lost or reordered. Deterministic per seed.

var delay := 6
var jitter := 0
var loss := 0.0
var rng := RandomNumberGenerator.new()
var _q: Array = []        # [due_tick, bytes]

func _init(delay_ticks := 6, jitter_ticks := 0, loss_rate := 0.0, seed := 1) -> void:
	delay = delay_ticks; jitter = jitter_ticks; loss = loss_rate; rng.seed = seed

func push(b: PackedByteArray, now: int) -> void:
	if loss > 0.0 and rng.randf() < loss: return
	_q.append([now + delay + (rng.randi_range(0, jitter) if jitter > 0 else 0), b])

func pop_due(now: int) -> Array:
	var out := []
	var keep := []
	for e in _q:
		if e[0] <= now: out.append(e[1])
		else: keep.append(e)
	_q = keep
	return out
