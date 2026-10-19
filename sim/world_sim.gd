class_name WorldSim
extends RefCounted
## The whole match simulation: two fighters, fixed 60 Hz ticks, deterministic for the same inputs and seed.
## step([p1_input, p2_input]) with inputs { left, right, up, down, buttons }.

var tick := 0
var rng := RandomNumberGenerator.new()
var fighters: Array[FighterSim] = []

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

func step(inputs: Array) -> void:
	tick += 1
	for f in fighters:
		var o := fighters[1 - f.idx]
		if f.grounded() and f.actionable() and absf(o.x - f.x) > 0.5: f.facing = 1 if o.x > f.x else -1
	for f in fighters: f.step(clean(inputs[f.idx]))
	_separate()
	_clamp()

# Push boxes never overlap: split the overlap between both fighters (walls take the share a cornered fighter cannot).
func _separate() -> void:
	var a := fighters[0]; var b := fighters[1]
	var ra := a.push_box(); var rb := b.push_box()
	if not ra.intersects(rb): return
	var overlap := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	if overlap <= 0.0: return
	var dir := 1.0 if a.x < b.x or (a.x == b.x and a.facing > 0) else -1.0
	if a.state == "air" or b.state == "air":   # airborne bodies drift apart 1 px/tick, so a jump can cross over (v1 rule)
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
	var at_wall := func(f: FighterSim) -> bool: return f.x <= SimConst.STAGE_MIN or f.x >= SimConst.STAGE_MAX
	if a.state == "air" or b.state == "air" or not (at_wall.call(a) or at_wall.call(b)): return
	var ra := a.push_box(); var rb := b.push_box()
	if ra.intersects(rb):
		var overlap := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
		var walled := a if at_wall.call(a) else b
		var other := b if walled == a else a
		other.x += signf(other.x - walled.x) * overlap

func snapshot() -> Dictionary:
	return { "tick": tick, "f": fighters.map(func(f: FighterSim) -> Dictionary: return f.snapshot()) }
