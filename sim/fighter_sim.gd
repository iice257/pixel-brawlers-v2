class_name FighterSim
extends RefCounted
## One fighter's simulation state. Pure data + rules, no nodes: stepped by WorldSim at 60 Hz, rendered by the fight scene.
## Moves come from data/fighters/<id>.json (Light / Medium / Heavy / Special / Block / Throw; Down = crouch, 2X = crouch variants).
## Attack hits are resolved by WorldSim; this class owns the per-fighter state machine and the effects of being hit.

const ACTIONABLE := ["idle", "walk_f", "walk_b", "crouch", "guard", "cguard"]
const AIR_STATES := ["air", "airatk", "launched"]
const THROWABLE := ["idle", "walk_f", "walk_b", "crouch", "guard", "cguard", "landlag"]
const TRACKED_BUTTONS := [SimConst.L, SimConst.M, SimConst.H, SimConst.S, SimConst.THROW]

var id: String
var idx: int
var stats: Dictionary
var moves: Dictionary           # move id -> move table (data)
var hp := 0
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var kb := 0.0                   # knockback slide, screen direction, decays each tick
var facing := 1                 # +1 faces right, -1 faces left
var state := "idle"
var st := 0                     # ticks spent in the current state (attacks: 1 on the tick the move starts)
var jump_dir := 0               # facing-relative: +1 forward, -1 back, 0 neutral
var hitstop := 0                # frozen ticks left (set by a connecting hit, on both fighters)
var stun_len := 0               # length of hit / block / landlag / lying state in ticks
var invuln := 0                 # strike-invulnerable ticks left (wakeup)
var cur: Dictionary = {}        # move being played
var connected := false          # current move hit or was blocked (opens cancels)
var hits_done: Array = []       # hit entries of the current move that already connected
var chain: Array = []           # weights used in the current chain
var air_used := false
var hit_heavy := false
var crouch_block := false       # the blockstun we are in came from a crouch block
var hard_kd := false
var ko := false
var juggle := 0                 # juggle points left while launched
var combo_hits := 0             # hits taken in the current combo (this fighter is the victim)
var press: Dictionary = {}      # button bit -> ticks since pressed (buffer)
var prev_buttons := 0
var throw_vx := 0.0
var throw_vy := 0.0
var throw_dmg := 0              # damage of the grab this fighter is held in, applied when the tech window closes
var throw_att := -1             # index of the grabbing fighter

static func load_data(fighter_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/fighters/%s.json" % fighter_id, FileAccess.READ)
	assert(f != null, "missing fighter data: " + fighter_id)
	return JSON.parse_string(f.get_as_text())

func _init(fighter_id: String, index: int, start_x: float, face: int) -> void:
	var d := load_data(fighter_id)
	id = fighter_id; idx = index; stats = d.stats; moves = d.moves
	reset(start_x, face)

## Back to the start of a round: full HP, standing, buffers cleared.
func reset(start_x: float, face: int) -> void:
	hp = int(stats.hp)
	x = start_x; y = 0.0; vx = 0.0; vy = 0.0; kb = 0.0; facing = face
	state = "idle"; st = 0; jump_dir = 0; hitstop = 0; stun_len = 0; invuln = 0
	cur = {}; connected = false; hits_done = []; chain = []; air_used = false
	hit_heavy = false; crouch_block = false; hard_kd = false; ko = false; juggle = 0; combo_hits = 0
	press = {}; prev_buttons = 0; throw_vx = 0.0; throw_vy = 0.0; throw_dmg = 0; throw_att = -1

func set_state(s: String) -> void:
	if s != state: state = s; st = 0

func airborne() -> bool:
	return state in AIR_STATES

func grounded() -> bool:
	return y <= 0.0 and not airborne()

func actionable() -> bool:
	return state in ACTIONABLE

func attacking() -> bool:
	return state == "attack" or state == "airatk"

## Can a hit land on this fighter right now?
func hittable() -> bool:
	return invuln <= 0 and not ko and state != "lying" and state != "thrown" and state != "win"

## Can the fighter block a hit of this level now? (mid: any guard; low: crouch guard only; overhead: standing guard only)
func can_block(level: String) -> bool:
	if level == "overhead": return state == "guard" or (state == "blockstun" and not crouch_block)
	if state == "cguard" or (state == "blockstun" and crouch_block): return true
	if state == "guard" or state == "blockstun": return level != "low"
	return false

## Stance used for boxes: stand / crouch / air / lying.
func stance() -> String:
	if airborne(): return "air"
	if state == "lying" or state == "ko": return "lying"
	if state == "crouch" or state == "prejump" or state == "cguard": return "crouch"
	if state == "attack" and cur.get("stance", "stand") == "crouch": return "crouch"
	if state == "blockstun" and crouch_block: return "crouch"
	return "stand"

## The animation-contract name this state plays (see fighters/anim_contract.gd).
func anim() -> String:
	match state:
		"prejump": return "crouch"
		"air": return "jump_f" if jump_dir > 0 else "jump_b" if jump_dir < 0 else "jump_up"
		"attack", "airatk": return cur.get("anim", cur.get("id", "idle"))
		"guard": return "block_stand"
		"cguard": return "block_crouch"
		"blockstun": return "block_crouch" if crouch_block else "block_stand"
		"hit", "thrown": return "hit_heavy" if hit_heavy or state == "thrown" else "hit_light"
		"launched", "lying": return "knockdown"
		"getup": return "wakeup"
		"landlag", "tech": return "idle"
		_: return state

# ---------------------------------------------------------------- input buffer

## Called every tick by the world, also during hitstop, so presses are never lost.
func feed(inp: Dictionary) -> void:
	var b: int = inp.buttons
	for bit in TRACKED_BUTTONS:
		if (b & bit) != 0 and (prev_buttons & bit) == 0:
			press[bit] = 0
		elif press.has(bit):
			press[bit] += 1
			if press[bit] >= SimConst.PRESS_BUFFER: press.erase(bit)
	prev_buttons = b

func _take(bit: int) -> bool:
	if press.has(bit):
		press.erase(bit)
		return true
	return false

# ---------------------------------------------------------------- stepping

## One tick. inp = { left, right, up, down, buttons } with SOCD already resolved by WorldSim.
func step(inp: Dictionary) -> void:
	st += 1
	if invuln > 0: invuln -= 1
	if kb != 0.0:
		x += kb
		kb *= SimConst.KNOCKBACK_DECAY
		if absf(kb) < 0.05: kb = 0.0
	match state:
		"attack": _step_attack(inp)
		"air", "airatk": _step_air()
		"launched": _step_launched()
		"hit", "blockstun", "landlag", "tech":
			if st > stun_len: set_state("idle")
		"lying":
			if st > stun_len:
				set_state("getup"); invuln = SimConst.WAKE_INVULN
		"getup":
			if st > SimConst.GETUP: set_state("idle")
		"thrown":
			if st >= SimConst.THROW_RELEASE: _launch(throw_vx, throw_vy, true)
		"prejump":
			if st >= SimConst.PREJUMP:
				vy = SimConst.JUMP_VY * stats.jump
				vx = facing * (SimConst.JUMP_FWD if jump_dir > 0 else SimConst.JUMP_BACK if jump_dir < 0 else 0.0) * stats.jump
				air_used = false
				set_state("air")
	if actionable(): _step_actionable(inp)
	if not airborne(): x += vx
	if actionable(): combo_hits = 0

func _step_actionable(inp: Dictionary) -> void:
	var fwd := (1 if inp.right else 0) - (1 if inp.left else 0)     # screen direction
	var rel := fwd * facing                                            # +1 toward opponent
	chain = []; cur = {}; connected = false; crouch_block = false
	if (inp.buttons & SimConst.BL) != 0:
		vx = 0.0
		set_state("cguard" if inp.down and not inp.up else "guard")
		return
	var mid := _pick_ground_move(inp.down and not inp.up)
	if mid != "":
		_start_move(moves[mid], false); return
	if inp.up:
		jump_dir = rel; vx = 0.0
		set_state("prejump")
	elif inp.down:
		vx = 0.0; set_state("crouch")
	elif rel > 0:
		vx = facing * stats.walk_f; set_state("walk_f")
	elif rel < 0:
		vx = -facing * stats.walk_b; set_state("walk_b")
	else:
		vx = 0.0; set_state("idle")

## Move id for the buffered press with the highest priority, "" if none. crouching picks the 2X variant when the fighter has one.
func _pick_ground_move(crouching: bool) -> String:
	if moves.has("throw") and _take(SimConst.THROW): return "throw"
	for pair in SimConst.ATTACK_BUTTONS:
		var mid: String = pair[0]
		if crouching and moves.has("2" + mid): mid = "2" + mid
		if not moves.has(mid) or moves[mid].kind != "ground" or not press.has(pair[1]): continue
		_take(pair[1])
		return mid
	return ""

func _start_move(m: Dictionary, keep_chain: bool) -> void:
	var chained := chain.duplicate()
	cur = m; connected = false; hits_done = []
	vx = 0.0
	chain = chained if keep_chain else []
	chain.append(m.weight)
	state = "airatk" if m.kind == "air" else "attack"
	st = 1

func _move_total(m: Dictionary) -> int:
	return int(m.startup) + int(m.active) + int(m.recovery)

func _step_attack(inp: Dictionary) -> void:
	if st > _move_total(cur):
		cur = {}; chain = []; connected = false
		set_state("idle")
		return
	if not connected: return
	var s := int(cur.startup); var a := int(cur.active)
	var crouching: bool = inp.down and not inp.up
	if cur.cancels.get("special", false) and moves.has("S") and st > s and st <= s + a + SimConst.SPECIAL_WINDOW:
		if press.has(SimConst.S) and moves["S"].kind == "ground":
			_take(SimConst.S)
			_start_move(moves["S"], true)
			return
	if cur.cancels.get("chain", false) and st > s and st <= s + a + SimConst.CHAIN_WINDOW:
		for pair in [["H", SimConst.H], ["M", SimConst.M], ["L", SimConst.L]]:
			var mid: String = pair[0]
			if crouching and moves.has("2" + mid): mid = "2" + mid
			var m = moves.get(mid)
			if m == null or m.kind != "ground" or m.weight <= cur.weight or chain.has(m.weight): continue
			if _take(pair[1]):
				_start_move(m, true)
				return

func _step_air() -> void:
	if state == "air" and not air_used:
		for pair in [["jH", SimConst.H], ["jM", SimConst.M], ["jL", SimConst.L]]:
			if moves.has(pair[0]) and _take(pair[1]):
				air_used = true
				_start_move(moves[pair[0]], false)
				break
	elif state == "airatk" and st > _move_total(cur):
		cur = {}; connected = false
		set_state("air")
	x += vx
	y += vy - stats.gravity / 2.0
	vy -= stats.gravity
	if y <= 0.0 and vy < 0.0:
		y = 0.0; vy = 0.0; vx = 0.0; jump_dir = 0
		var lag := 0
		if state == "airatk" and not connected: lag = int(cur.get("land_lag", 0))
		cur = {}; connected = false; chain = []
		if lag > 0:
			stun_len = lag; set_state("landlag")
		else:
			set_state("idle")

func _step_launched() -> void:
	x += vx
	y += vy - stats.gravity / 2.0
	vy -= stats.gravity
	if y <= 0.0 and vy < 0.0:
		y = 0.0; vy = 0.0; vx = 0.0; juggle = 0
		if ko:
			set_state("ko")
		else:
			stun_len = SimConst.LIE_HARD if hard_kd else SimConst.LIE_SOFT
			set_state("lying")

func _launch(lvx: float, lvy: float, hard: bool) -> void:
	vx = lvx; vy = lvy
	y = maxf(y, 0.01)
	hard_kd = hard_kd or hard
	cur = {}; connected = false; chain = []
	set_state("launched")

# ---------------------------------------------------------------- being hit

## Apply one connecting hit. away = screen direction from the attacker to this fighter. Returns damage dealt.
func receive_hit(h: Dictionary, away: int, att_pwr: float) -> int:
	var was_launched := state == "launched"
	var was_air := state == "air" or state == "airatk"
	combo_hits += 1
	var pct: int = maxi(SimConst.SCALE[mini(combo_hits - 1, SimConst.SCALE.size() - 1)], SimConst.SCALE_FLOOR)
	var dmg := int(roundf(h.dmg * att_pwr * stats.get("def", 1.0) * pct / 100.0))
	hp = maxi(0, hp - dmg)
	if hp <= 0: ko = true
	var stun := int(h.hitstun)
	if combo_hits >= 7: stun = int(roundf(stun * SimConst.STUN_DECAY_7))
	elif combo_hits >= 4: stun = int(roundf(stun * SimConst.STUN_DECAY_4))
	stun = maxi(stun, 1)
	hitstop = int(h.hitstop)
	hit_heavy = h.heavy
	crouch_block = false
	cur = {}; connected = false; chain = []
	var kd: String = h.kd
	if was_launched:
		juggle = maxi(0, juggle - int(h.juggle_cost))
		if kd == "none": _launch(away * SimConst.AIR_HIT_VX, SimConst.AIR_HIT_VY, false)
		else: _launch(away * h.launch[0], h.launch[1], kd == "hard")
	elif was_air:
		juggle = 0
		if kd == "none": _launch(away * SimConst.AIR_HIT_VX, SimConst.AIR_HIT_VY, false)
		else: _launch(away * h.launch[0], h.launch[1], kd == "hard")
	elif kd != "none":
		hard_kd = false
		_launch(away * h.launch[0], h.launch[1], kd == "hard")
		juggle = int(h.get("juggle_start", 0))
	elif ko:
		hard_kd = false
		_launch(away * SimConst.AIR_HIT_VX, SimConst.AIR_HIT_VY, false)
	else:
		vx = 0.0; stun_len = stun; kb = away * h.pb_hit
		set_state("hit")
	return dmg

func receive_block(h: Dictionary, away: int) -> void:
	hitstop = maxi(0, int(h.hitstop) - SimConst.BLOCK_HITSTOP_LOSS)
	crouch_block = state == "cguard" or (state == "blockstun" and crouch_block)
	stun_len = int(h.blockstun); kb = away * h.pb_block
	vx = 0.0; cur = {}; connected = false; chain = []
	set_state("blockstun")

## Grabbed: held for THROW_RELEASE ticks, then thrown into a hard knockdown. The damage lands when the tech window closes
## (WorldSim calls apply_throw_damage); a tech cancels it.
func receive_throw(dmg: int, away: int, launch: Array, stop: int, attacker: int) -> void:
	combo_hits = 1
	throw_dmg = dmg; throw_att = attacker
	hitstop = stop
	vx = 0.0; kb = 0.0; cur = {}; connected = false; chain = []; crouch_block = false
	throw_vx = away * launch[0]; throw_vy = launch[1]
	hard_kd = false
	set_state("thrown")

func apply_throw_damage() -> void:
	hp = maxi(0, hp - throw_dmg)
	if hp <= 0: ko = true
	throw_dmg = 0

## Throw tech (either fighter): the grab is cancelled, no damage, both slide apart and are neutral after TECH_STUN ticks.
func receive_tech(away: int) -> void:
	throw_dmg = 0; throw_att = -1; combo_hits = 0
	hitstop = 0; vx = 0.0; cur = {}; connected = false; chain = []; crouch_block = false
	kb = away * SimConst.TECH_KB
	stun_len = SimConst.TECH_STUN
	set_state("tech")

# ---------------------------------------------------------------- boxes

## World-space box [x, y, w, h] (y up) from a facing-right local box.
func to_world(b: Array) -> Rect2:
	var bx: float = b[0] if facing > 0 else -b[0] - b[2]
	return Rect2(x + bx, y + b[1], b[2], b[3])

func push_box() -> Rect2:
	return to_world(SimConst.BOXES[stance()].push)

func hurt_boxes() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b in SimConst.BOXES[stance()].hurt: out.append(to_world(b))
	return out

## Hit entries of the current move that are live this tick and have not connected yet: [[index, hit]...].
func active_hits() -> Array:
	var out := []
	if not attacking() or not cur.has("hits"): return out
	for i in cur.hits.size():
		var h: Dictionary = cur.hits[i]
		if st >= int(h["from"]) and st <= int(h["to"]) and not hits_done.has(i): out.append([i, h])
	return out

func hit_rect(h: Dictionary) -> Rect2:
	return to_world(h.box)

func snapshot() -> Dictionary:
	return { "x": x, "y": y, "vx": vx, "vy": vy, "kb": kb, "facing": facing, "state": state, "st": st, "jump_dir": jump_dir,
		"hp": hp, "hitstop": hitstop, "move": cur.get("id", ""), "connected": connected, "chain": chain.duplicate(),
		"juggle": juggle, "combo": combo_hits, "invuln": invuln, "ko": ko }
