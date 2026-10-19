class_name FighterSim
extends RefCounted
## One fighter's simulation state. Pure data + rules, no nodes: stepped by WorldSim at 60 Hz, rendered by the fight scene.
## G0 covers locomotion only (idle, walk, crouch, jump). Combat states arrive in G1.

const ACTIONABLE := ["idle", "walk_f", "walk_b", "crouch"]

var id: String
var idx: int
var stats: Dictionary
var moves: Array
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var facing := 1                 # +1 faces right, -1 faces left
var state := "idle"
var st := 0                     # ticks spent in the current state
var jump_dir := 0               # facing-relative: +1 forward, -1 back, 0 neutral

static func load_data(fighter_id: String) -> Dictionary:
	var f := FileAccess.open("res://data/fighters/%s.json" % fighter_id, FileAccess.READ)
	assert(f != null, "missing fighter data: " + fighter_id)
	return JSON.parse_string(f.get_as_text())

func _init(fighter_id: String, index: int, start_x: float, face: int) -> void:
	var d := load_data(fighter_id)
	id = fighter_id; idx = index; stats = d.stats; moves = d.moves
	x = start_x; facing = face

func set_state(s: String) -> void:
	if s != state: state = s; st = 0

func grounded() -> bool:
	return y <= 0.0 and state != "air"

func actionable() -> bool:
	return state in ACTIONABLE

## Stance used for boxes: stand / crouch / air.
func stance() -> String:
	if state == "air": return "air"
	if state == "crouch" or state == "prejump": return "crouch"
	return "stand"

## The animation-contract name this state plays (see fighters/anim_contract.gd).
func anim() -> String:
	match state:
		"prejump": return "crouch"
		"air": return "jump_f" if jump_dir > 0 else "jump_b" if jump_dir < 0 else "jump_up"
		_: return state

## One tick. inp = { left, right, up, down, buttons } with SOCD already resolved by WorldSim.
func step(inp: Dictionary) -> void:
	st += 1
	var fwd := (1 if inp.right else 0) - (1 if inp.left else 0)     # screen direction
	var rel := fwd * facing                                            # +1 toward opponent
	match state:
		"idle", "walk_f", "walk_b", "crouch":
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
		"prejump":
			if st >= SimConst.PREJUMP:
				vy = SimConst.JUMP_VY * stats.jump
				vx = facing * (SimConst.JUMP_FWD if jump_dir > 0 else SimConst.JUMP_BACK if jump_dir < 0 else 0.0) * stats.jump
				set_state("air")
		"air":
			pass
	x += vx
	if state == "air":
		y += vy - stats.gravity / 2.0
		vy -= stats.gravity
		if y <= 0.0 and vy < 0.0:
			y = 0.0; vy = 0.0; vx = 0.0; jump_dir = 0
			set_state("idle")

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

func snapshot() -> Dictionary:
	return { "x": x, "y": y, "vx": vx, "vy": vy, "facing": facing, "state": state, "st": st, "jump_dir": jump_dir }
