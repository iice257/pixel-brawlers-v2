class_name WorldSim
extends RefCounted
## The whole fight simulation: two fighters, fixed 60 Hz ticks, deterministic for the same inputs and seed.
## step([p1_input, p2_input]) with inputs { left, right, up, down, buttons }.
## `events` is rebuilt every step for presentation: { type: hit | block | grab | throw | tech | ko, att, def, dmg, tick }.
## grab = a throw connected (no damage yet); throw = its damage landed after the tech window; tech = the grab was broken.

var tick := 0
var rng := RandomNumberGenerator.new()
var fighters: Array[FighterSim] = []
var events: Array = []

func _init(p1 := "placeholder", p2 := "placeholder", seed := 1) -> void:
	rng.seed = seed
	fighters = [FighterSim.new(p1, 0, SimConst.START_X[0], 1), FighterSim.new(p2, 1, SimConst.START_X[1], -1)]

static func neutral() -> Dictionary:
	return { "left": false, "right": false, "up": false, "down": false, "buttons": 0 }

## SOCD: left + right = neutral, up + down = up.
static func clean(raw: Dictionary) -> Dictionary:
	var i := neutral()
	i.buttons = raw.get("buttons", 0)
	var l: bool = raw.get("left", false); var r: bool = raw.get("right", false)
	i.left = l and not r; i.right = r and not l
	i.up = raw.get("up", false); i.down = raw.get("down", false) and not i.up
	return i

## Back to round start positions, full HP, fresh buffers. Wins and timers live in MatchSim.
func reset_round() -> void:
	fighters[0].reset(SimConst.START_X[0], 1)
	fighters[1].reset(SimConst.START_X[1], -1)
	events.clear()

func step(inputs: Array) -> void:
	tick += 1
	events.clear()
	var ci := [clean(inputs[0]), clean(inputs[1])]
	for f in fighters:
		var o := fighters[1 - f.idx]
		if f.grounded() and f.actionable() and absf(o.x - f.x) > 0.5: f.facing = 1 if o.x > f.x else -1
	for f in fighters: f.feed(ci[f.idx])
	for f in fighters:
		if f.hitstop > 0: f.hitstop -= 1
		else: f.step(ci[f.idx])
	_resolve()
	_throw_holds()
	_separate()
	_clamp()

# ---------------------------------------------------------------- hits

func _at_wall(f: FighterSim) -> bool:
	return f.x <= SimConst.STAGE_MIN + 0.5 or f.x >= SimConst.STAGE_MAX - 0.5

func _resolve() -> void:
	var results := []
	var a := fighters[0]; var b := fighters[1]
	var mutual := _grabbing(a) and _grabbing(b) and absf(a.x - b.x) <= minf(float(a.cur.range), float(b.cur.range))
	if mutual: _tech(a, b)
	for f in fighters:
		var o := fighters[1 - f.idx]
		if mutual or not f.attacking(): continue
		if f.cur.kind == "throw":
			if _grabbing(f): _try_throw(f, o)
			continue
		for pair in f.active_hits():
			var h: Dictionary = pair[1]
			if not o.hittable(): continue
			var hr := f.hit_rect(h)
			var touching := false
			for hb in o.hurt_boxes():
				if hr.intersects(hb): touching = true; break
			if not touching: continue
			if o.state == "launched" and o.juggle < int(h.juggle_cost): continue
			results.append({ "f": f, "o": o, "i": pair[0], "h": h, "blocked": o.can_block(h.get("level", "mid")) })
			break
	for r in results: _apply(r)

func _apply(r: Dictionary) -> void:
	var f: FighterSim = r.f; var o: FighterSim = r.o; var h: Dictionary = r.h
	var away := 1 if o.x > f.x else -1 if o.x < f.x else f.facing
	f.hits_done.append(r.i)
	var pb: float
	if r.blocked:
		o.receive_block(h, away)
		pb = h.pb_block
		events.append({ "type": "block", "att": f.idx, "def": o.idx, "dmg": 0, "tick": tick, "heavy": h.heavy })
	else:
		var was_ko := o.ko
		var dmg := o.receive_hit(h, away, f.stats.get("pwr", 1.0))
		pb = h.pb_hit
		events.append({ "type": "hit", "att": f.idx, "def": o.idx, "dmg": dmg, "tick": tick, "heavy": h.heavy, "level": h.get("level", "mid") })
		if o.ko and not was_ko: events.append({ "type": "ko", "att": f.idx, "def": o.idx, "dmg": dmg, "tick": tick })
	f.connected = true
	f.hitstop = o.hitstop
	if _at_wall(o): f.kb = -away * pb * SimConst.CORNER_SHARE

func _try_throw(f: FighterSim, o: FighterSim) -> void:
	var m := f.cur
	if not (o.state in FighterSim.THROWABLE) or o.invuln > 0 or o.y > 0.0 or f.y > 0.0: return
	if absf(o.x - f.x) > float(m.range): return
	var away := 1 if o.x > f.x else -1 if o.x < f.x else f.facing
	var was_ko := o.ko
	var dmg := int(roundf(m.dmg * f.stats.get("pwr", 1.0) * o.stats.get("def", 1.0)))
	o.receive_throw(dmg, away, m.launch, int(m.hitstop), f.idx)
	f.connected = true
	f.hitstop = int(m.hitstop)
	events.append({ "type": "grab", "att": f.idx, "def": o.idx, "dmg": 0, "tick": tick })

## Is this fighter on the tick its throw connects (or whiffs)?
func _grabbing(f: FighterSim) -> bool:
	return f.attacking() and f.cur.kind == "throw" and f.st == int(f.cur.startup) + 1 and not f.connected

## A grabbed fighter can tech with a fresh Throw press on ticks 1..TECH_WINDOW after the grab; on the next tick the damage lands.
func _throw_holds() -> void:
	for o in fighters:
		if o.state != "thrown" or o.throw_att < 0: continue
		var f := fighters[o.throw_att]
		if o.st <= SimConst.TECH_WINDOW:
			if o.press.get(SimConst.THROW, -1) == 0: _tech(f, o)
		elif o.st == SimConst.TECH_WINDOW + 1:
			var was_ko := o.ko
			var dmg := o.throw_dmg
			o.apply_throw_damage()
			events.append({ "type": "throw", "att": f.idx, "def": o.idx, "dmg": dmg, "tick": tick })
			if o.ko and not was_ko: events.append({ "type": "ko", "att": f.idx, "def": o.idx, "dmg": dmg, "tick": tick })

func _tech(a: FighterSim, b: FighterSim) -> void:
	var dir := 1 if b.x > a.x else -1 if b.x < a.x else a.facing   # screen direction from a to b
	a.receive_tech(-dir)
	b.receive_tech(dir)
	events.append({ "type": "tech", "att": a.idx, "def": b.idx, "dmg": 0, "tick": tick })

# ---------------------------------------------------------------- spacing

# Push boxes never overlap: split the overlap between both fighters (walls take the share a cornered fighter cannot).
func _separate() -> void:
	var a := fighters[0]; var b := fighters[1]
	var ra := a.push_box(); var rb := b.push_box()
	if not ra.intersects(rb): return
	var overlap := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	if overlap <= 0.0: return
	var dir := 1.0 if a.x < b.x or (a.x == b.x and a.facing > 0) else -1.0
	if a.airborne() or b.airborne():   # airborne bodies drift apart 1 px/tick, so a jump can cross over (v1 rule)
		var d := minf(overlap, 1.0) / 2.0
		a.x -= dir * d; b.x += dir * d
		return
	a.x -= dir * overlap / 2.0; b.x += dir * overlap / 2.0

func _clamp() -> void:
	var a := fighters[0]; var b := fighters[1]
	var sep := absf(b.x - a.x)
	if sep > SimConst.MAX_SEP:
		var mid := (a.x + b.x) / 2.0; var half := SimConst.MAX_SEP / 2.0
		var s := signf(b.x - a.x)
		a.x = mid - s * half; b.x = mid + s * half
	for f in fighters: f.x = clampf(f.x, SimConst.STAGE_MIN, SimConst.STAGE_MAX)
	# a fighter pinned by the wall pushes the other one out instead of overlapping
	if a.airborne() or b.airborne() or not (_at_wall(a) or _at_wall(b)): return
	var ra := a.push_box(); var rb := b.push_box()
	if ra.intersects(rb):
		var overlap := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
		var walled := a if _at_wall(a) else b
		var other := b if walled == a else a
		other.x += signf(other.x - walled.x) * overlap

func snapshot() -> Dictionary:
	return { "tick": tick, "f": fighters.map(func(f: FighterSim) -> Dictionary: return f.snapshot()) }

## Full state for rollback netcode: restore(save()) then replaying the same inputs reproduces the same ticks.
func save() -> Dictionary:
	return { "tick": tick, "rng_seed": rng.seed, "rng_state": rng.state, "f": fighters.map(func(f: FighterSim) -> Dictionary: return f.save()) }

func restore(s: Dictionary) -> void:
	tick = s.tick
	rng.seed = s.rng_seed; rng.state = s.rng_state
	for i in fighters.size(): fighters[i].restore(s.f[i])
	events.clear()

## Per-tick checksum of everything in save(); two peers that agree on it are in sync.
func checksum() -> int:
	return hash(var_to_str(save()))
