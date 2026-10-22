class_name CpuBrain
extends RefCounted
## CPU opponent (docs/ref/GAME_DESIGN.md section 7): one parameterised controller for tiers 1..8. It outputs the same input struct as a human,
## sees only the opponent's state `reaction` ticks ago (never the current tick), and plays moves through scripted per-tick inputs, so its
## moves have the same recovery and can whiff. Deterministic: its own seeded RNG, no engine randomness.

## tier -> [reaction, blockSkill, antiAir, punish, comboSkill, mixup, aggression]
const TIERS := {
	1: [28, 0.15, 0.05, 0.05, 0.10, 0.10, 0.25], 2: [24, 0.30, 0.10, 0.10, 0.20, 0.20, 0.35],
	3: [20, 0.45, 0.20, 0.20, 0.30, 0.30, 0.45], 4: [16, 0.55, 0.35, 0.30, 0.45, 0.40, 0.55],
	5: [13, 0.68, 0.50, 0.45, 0.60, 0.50, 0.60], 6: [10, 0.78, 0.65, 0.60, 0.75, 0.60, 0.68],
	7: [8, 0.88, 0.80, 0.75, 0.90, 0.70, 0.75], 8: [6, 0.95, 0.92, 0.90, 1.00, 0.80, 0.82],
}
const HALF_W := 16.0           # opponent hurt-box half width: a move reaches when gap <= box edge + this

var tier := 4
var rng := RandomNumberGenerator.new()
var me := 1                    # fighter index this brain drives
var reaction := 16
var block_skill := 0.5
var anti_air := 0.3
var punish := 0.3
var combo_skill := 0.45
var mixup := 0.4
var aggression := 0.5
var _hist: Array = []          # recent observations of the opponent, newest last
var _q: Array = []             # scripted inputs still to play
var _seen := -1                # attack key already decided on (so one decision per opposing attack)
var _block_until := 0
var _block_low := false
var _walk := 0                 # remaining ticks of a held walk, signed: +toward, -away
var _t := 0

func _init(t := 4, idx := 1, seed := 7) -> void:
	set_tier(t); me = idx; rng.seed = seed

func set_tier(t: int) -> void:
	tier = clampi(t, 1, 8)
	var p: Array = TIERS[tier]
	reaction = p[0]; block_skill = p[1]; anti_air = p[2]; punish = p[3]; combo_skill = p[4]; mixup = p[5]; aggression = p[6]

## One tick: returns { left, right, up, down, buttons } in screen directions.
func think(f: Array) -> Dictionary:
	_t += 1
	var m: FighterSim = f[me]; var o: FighterSim = f[1 - me]
	_hist.append({"gap": absf(o.x - m.x), "st": o.state, "o": o.st, "cur": o.cur.duplicate(), "air": o.airborne(), "crouch": o.stance() == "crouch", "combo": o.combo_hits})
	if _hist.size() > 40: _hist.pop_front()
	var seen: Dictionary = _hist[maxi(_hist.size() - 1 - reaction, 0)]
	var dir := 1 if o.x > m.x else -1                       # screen direction towards the opponent
	if not _q.is_empty():
		var qi: Dictionary = _q.pop_front()
		return _mk(qi, dir)
	if _t < _block_until: return _mk({"bl": true, "dn": _block_low}, dir)
	if not (m.actionable() or (m.state == "attack" and m.connected)): return _mk({}, dir)
	var gap: float = seen.gap
	# 1. defend against an attack that has started and is close
	if seen.st in ["attack", "airatk"] and seen.cur.has("startup"):
		var reach := _reach(seen.cur)
		if gap <= reach + HALF_W + 26.0:
			var left: int = int(seen.cur.startup) + int(seen.cur.active) - int(seen.o)
			var key := _t - int(seen.o)                              # the tick this attack began (one decision per attack)
			if key != _seen:
				_seen = key
				if rng.randf() < block_skill and left >= -2:
					var low := _level(seen.cur) == "low"
					if rng.randf() < 0.3 * (1.0 - block_skill) / 0.85: low = not low      # low tiers guard the wrong height
					_block_low = low; _block_until = _t + maxi(left + 6, 4)
					return _mk({"bl": true, "dn": low}, dir)
	# punish a whiffed or blocked move still in its recovery
	if seen.st == "attack" and seen.cur.has("startup") and seen.o > int(seen.cur.startup) + int(seen.cur.active) and gap < 64.0 and rng.randf() < punish * 0.25:
		return _attack("2L" if gap < 52.0 and mixup > rng.randf() else "L", m, dir)
	# anti-air
	if seen.air and gap < 90.0 and m.actionable() and rng.randf() < anti_air * 0.35:
		return _attack("H" if m.moves.has("H") else "L", m, dir)
	# combo: keep pressing after a confirmed hit
	if o.state in ["hit", "launched"] and m.state == "attack" and m.connected:
		if rng.randf() < combo_skill: return _attack(["L", "M", "H"][mini(maxi(o.combo_hits - 1, 0), 2)], m, dir)
		return _mk({}, dir)
	if not m.actionable(): return _mk({}, dir)
	# pressure: opponent in block/hit stun
	if o.state in ["blockstun", "hit"] and gap < 70.0 and rng.randf() < aggression:
		var r := rng.randf()
		if r < mixup * 0.4 and gap < 44.0: return _attack("throw", m, dir)
		elif r < mixup: return _attack("2L" if gap < 56.0 else "L", m, dir)
		return _attack("L" if gap < 50.0 else "M", m, dir)
	# neutral
	if _walk != 0:
		_walk -= signi(_walk)
		return _mk({"fwd": 1 if _walk > 0 else -1}, dir)
	if rng.randf() < 0.1 + aggression * 0.14:
		var want := 52.0
		if gap > want + 14.0:
			if rng.randf() < 0.07 + aggression * 0.05 and m.moves.has("jM"): return _jump(dir, gap)
			_walk = rng.randi_range(8, 24); return _mk({"fwd": 1}, dir)
		if gap < want - 20.0:
			if rng.randf() < 0.2 * tier / 8.0 and m.moves.has("throw"): return _attack("throw", m, dir)
			_walk = -rng.randi_range(6, 14); return _mk({"fwd": -1}, dir)
		var pick: String = ["L", "2L", "M", "H", "S"][rng.randi_range(0, mini(1 + tier / 2, 4))]
		if tier == 8 and rng.randf() < 0.05: return _mk({}, dir)         # whiffs a few percent so even tier 8 is beatable
		return _attack(pick, m, dir)
	return _mk({}, dir)

func _reach(mv: Dictionary) -> float:
	var r := 0.0
	for h in mv.get("hits", []): r = maxf(r, float(h.box[0]) + float(h.box[2]))
	return maxf(r, float(mv.get("range", 0.0)))

func _level(mv: Dictionary) -> String:
	var hits: Array = mv.get("hits", [])
	return String(hits[0].get("level", "mid")) if not hits.is_empty() else "mid"

func _attack(id: String, m: FighterSim, dir: int) -> Dictionary:
	var crouch := id.begins_with("2")
	var bit: int = SimConst.THROW if id == "throw" else {"L": SimConst.L, "M": SimConst.M, "H": SimConst.H, "S": SimConst.S}[id.trim_prefix("2")]
	return _mk({"btn": bit, "dn": crouch}, dir)

func _jump(dir: int, gap: float) -> Dictionary:
	_q = [{"up": true, "fwd": 1}, {"up": true, "fwd": 1}]
	return _mk({"up": true, "fwd": 1}, dir)

## Builds the input struct: "fwd" is relative to the opponent (+1 towards), "bl" block, "dn" crouch, "btn" a button bit.
func _mk(d: Dictionary, dir: int) -> Dictionary:
	var i := WorldSim.neutral()
	var fwd: int = d.get("fwd", 0) * dir
	i.right = fwd > 0; i.left = fwd < 0
	i.up = d.get("up", false); i.down = d.get("dn", false)
	var b := 0
	if d.get("bl", false): b |= SimConst.BL
	b |= int(d.get("btn", 0))
	i.buttons = b
	return i
