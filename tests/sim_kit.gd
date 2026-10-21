class_name TestKit
extends RefCounted
## Scripted-input helpers for sim tests. Schedules are sparse: { tick: input } holds each sample until the next listed tick.

static func inp(o := {}) -> Dictionary:
	var i := WorldSim.neutral()
	for k in o: i[k] = o[k]
	return i

static func btn(bits: int, extra := {}) -> Dictionary:
	var d := extra.duplicate(); d["buttons"] = bits
	return inp(d)

## Facing-relative direction helpers (P1 faces right, P2 faces left).
static func back(p := 0) -> Dictionary:
	return { "left": true } if p == 0 else { "right": true }

static func arena(gap := 40, seed := 1) -> WorldSim:
	var w := WorldSim.new("placeholder", "placeholder", seed)
	w.fighters[0].x = 288.0 - gap / 2.0
	w.fighters[1].x = 288.0 + gap / 2.0
	return w

static func _at(frames: Dictionary, t: int) -> Dictionary:
	if frames.has("buttons"): return frames          # a plain input held for the whole run
	var cur := WorldSim.neutral()
	var keys := frames.keys(); keys.sort()
	for k in keys:
		if k <= t: cur = frames[k]
		else: break
	return cur

## Run n ticks of scripted input (tick 0 is the first step). Stops early when `until` (Callable(world, t) -> bool) is true.
static func run(w: WorldSim, n: int, p1 := {}, p2 := {}, until := Callable()) -> void:
	for t in n:
		w.step([_at(p1, t), _at(p2, t)])
		if until.is_valid() and until.call(w, t): return

## First tick (0-based) on which pred(w) is true within n ticks, or -1.
static func first_tick(w: WorldSim, n: int, p1: Dictionary, p2: Dictionary, pred: Callable) -> int:
	var found := -1
	for t in n:
		w.step([_at(p1, t), _at(p2, t)])
		if pred.call(w):
			found = t
			break
	return found

## A press for one tick at t: { t: press, t+1: neutral }.
static func tap(t: int, bits: int, extra := {}) -> Dictionary:
	return { t: btn(bits, extra), t + 1: WorldSim.neutral() }

static func pad(rng: RandomNumberGenerator, who: int) -> Callable:
	var s := { "dir": 0, "hold": 0, "down": false, "block": false }
	return func(w: WorldSim) -> Dictionary:
		var me: FighterSim = w.fighters[who]; var foe: FighterSim = w.fighters[1 - who]
		if s.hold <= 0:
			s.hold = rng.randi_range(4, 24)
			var r := rng.randf()
			var toward := 1 if foe.x > me.x else -1
			s.dir = toward if r < 0.5 else -toward if r < 0.62 else 0
			s.down = rng.randf() < 0.18
			s.block = rng.randf() < 0.15
		s.hold -= 1
		var i := WorldSim.neutral()
		i.left = s.dir < 0; i.right = s.dir > 0
		i.down = s.down
		i.up = rng.randf() < 0.025
		var b := 0
		if s.block: b |= SimConst.BL
		var r2 := rng.randf()
		if r2 < 0.10: b |= SimConst.L
		elif r2 < 0.16: b |= SimConst.M
		elif r2 < 0.20: b |= SimConst.H
		elif r2 < 0.23: b |= SimConst.S
		elif r2 < 0.245: b |= SimConst.THROW
		i.buttons = b
		return i
