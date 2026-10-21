class_name FighterView
extends Node3D
## Draws one FighterSim as the baked 3D character. Pose timing comes from the sim (held key poses on attacks, stepped
## 12 fps loops); body position comes from the sim every tick, so motion stays smooth while the pose steps.

const WORLD_PER_PX := 0.018          # sim pixel -> metres (a 100 px fighter is 1.8 m)
const CENTER_X := 288.0
const STEP_FPS := 12.0
const HOLD_MIN := 4                  # impact pose is held at least this many sim ticks

# sim anim name -> clip (placeholder mapping until the Mixamo set lands; see docs/ASSETS.md)
const MOVE_CLIPS := { "L": "Punch_Jab", "M": "Punch_Cross", "H": "Melee_Hook", "S": "OverhandThrow",
	"2L": "Punch_Jab", "2M": "Punch_Cross", "2H": "Melee_Hook", "jL": "Punch_Jab", "jM": "Punch_Cross", "jH": "Melee_Hook", "throw": "OverhandThrow" }

static var _meta := {}

var sim: FighterSim
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var clock := 0.0
var meshes: Array[MeshInstance3D] = []
var lean := 0.0
var turn := 0.0
var ground := 0.0

## model_id selects res://fighters/<id>/model.scn (baked by tools/bake_fighter.sh); animations are shared by humanoid bone name.
func setup(fighter: FighterSim, model_id: String, swap: float) -> void:
	sim = fighter
	model = (load("res://fighters/%s/model.scn" % model_id) as PackedScene).instantiate()
	add_child(model)
	skeleton = model.get_node("Skeleton3D")
	player = AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library("", load("res://fighters/shared/anims.res"))
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://fighters/shared/clip_meta.json"))
	dress(skeleton, model_id)
	for mi in skeleton.get_children():
		if mi is MeshInstance3D:
			meshes.append(mi)
			mi.set_instance_shader_parameter("swap", swap)
	turn = deg_to_rad(90.0 * fighter.facing)

func _len(clip: String) -> float:
	return float(_meta[clip].length)

func _peak(clip: String) -> float:
	return float(_meta[clip].peak_t)

## [clip, time] for the fighter's current sim state.
func _pose() -> Array:
	var f := sim
	var a := f.anim()
	var loop_t := floorf(clock * STEP_FPS) / STEP_FPS
	if f.attacking() and MOVE_CLIPS.has(a):
		return [MOVE_CLIPS[a], _attack_time(MOVE_CLIPS[a], f)]
	match a:
		"idle", "win": return ["Punch_Jab", 0.0]    # boxing guard until Mixamo Fight Idle lands; the bob below keeps it alive
		"walk_f": return ["Walk", fposmod(loop_t, _len("Walk"))]
		"walk_b": return ["Walk", _len("Walk") - fposmod(loop_t, _len("Walk")) - 0.01]
		"crouch": return ["Crouch_Idle", fposmod(loop_t, _len("Crouch_Idle"))]
		"block_stand": return ["Punch_Jab", 0.0]
		"block_crouch": return ["Crouch_Idle", 0.2]
		"jump_up", "jump_f", "jump_b": return ["Jump", clampf(f.st / 60.0, 0.0, _len("Jump") - 0.05)]
		"hit_light": return ["Hit_Chest", _hit_time("Hit_Chest")]
		"hit_heavy": return ["Hit_Head", _hit_time("Hit_Head")]
		"knockdown":
			if f.state == "launched": return ["Hit_Knockback", clampf(_stepped(f.st / 60.0), 0.0, _len("Hit_Knockback") - 0.02)]
			return ["Death01", 1.45]
		"wakeup": return ["LayToIdle", clampf(float(f.st) / SimConst.GETUP, 0.0, 1.0) * (_len("LayToIdle") - 0.02)]
		"ko": return ["Death01", clampf(_stepped(f.st / 60.0), 0.0, _len("Death01") - 0.02)]
	return ["Idle", 0.0]

## The reaction clips are short; hold the mid-clip reaction pose for the stun and let the exaggeration do the selling.
func _hit_time(clip: String) -> float:
	return clampf(_stepped(0.5 * _len(clip) + sim.st / 60.0 * 0.4), 0.0, _len(clip) - 0.02)

func _stepped(t: float) -> float:
	return floorf(t * STEP_FPS) / STEP_FPS

## Held key poses: wind-up, snap to the impact pose, hold it through the active frames, follow-through, return.
func _attack_time(clip: String, f: FighterSim) -> float:
	var peak := _peak(clip)
	var s := int(f.cur.startup); var act := int(f.cur.active); var rec := int(f.cur.recovery)
	var st := f.st
	if st <= s:
		return peak * (0.3 if st <= int(ceil(s * 0.6)) else 0.72)           # anticipation, then the in-between before the snap
	if st <= s + maxi(act, HOLD_MIN): return peak                             # held impact pose
	var r := float(st - s - maxi(act, HOLD_MIN)) / float(maxi(rec - maxi(HOLD_MIN - act, 0), 1))
	var end_t := minf(_len(clip) * 0.85, peak + 0.4)
	if r < 0.35: return peak + minf(0.07, end_t - peak)
	if r < 0.75: return peak + (end_t - peak) * 0.55
	return end_t

func present(dt: float, tick: int) -> void:
	clock += dt
	var f := sim
	position.x = (f.x - CENTER_X) * WORLD_PER_PX
	position.y = f.y * WORLD_PER_PX
	var goal := deg_to_rad(90.0 * f.facing)
	turn = lerp_angle(turn, goal, 0.35)
	var pose := _pose()
	if player.current_animation != pose[0]:
		player.play(pose[0])
		player.pause()
	player.seek(pose[1], true)
	player.advance(0.0)
	_exaggerate(skeleton, _hit_k(f), f.state == "hit" and f.hit_heavy)
	var drop := _ground_drop(skeleton) if (f.state in ["lying", "ko", "getup"]) else 0.0
	ground = lerpf(ground, drop, 0.5)
	# lean into the held impact, pull back during wind-up and block
	var target := 0.0
	if f.attacking():
		var s := int(f.cur.startup)
		target = -4.0 if f.st <= s else 9.0 if f.st <= s + HOLD_MIN + 2 else 3.0
	elif f.state == "blockstun": target = -6.0
	lean = lerpf(lean, target, 0.45)
	model.basis = Basis(Vector3.UP, turn) * Basis(Vector3(0, 0, 1), deg_to_rad(-lean * f.facing))
	var shake := 0.0
	if f.hitstop > 0 and (f.state == "hit" or f.state == "blockstun" or f.state == "thrown"):
		shake = 0.015 * (1.0 if tick % 2 == 0 else -1.0)
	var bob := 0.012 * sin(floorf(clock * STEP_FPS) / STEP_FPS * TAU * 1.1) if f.state == "idle" else 0.0
	model.position = Vector3(shake, ground + bob, 0.0)
	var flash := 1.0 if (f.hitstop > 0 and f.state == "hit") else 0.0
	for mi in meshes: mi.set_instance_shader_parameter("flash", flash)

## Hit reaction strength 0..1: snaps on in 2 ticks, then eases off over the stun.
func _hit_k(f: FighterSim) -> float:
	if f.state != "hit" and f.state != "thrown": return 0.0
	var snap := clampf(f.st / 2.0, 0.0, 1.0)
	var fade := clampf(1.0 - float(f.st - 2) / maxf(f.stun_len, 6.0), 0.35, 1.0)
	return snap * fade

const BODY_BONES := ["UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes"]   # skeleton also has helper bones at the origin
const SNAP_BONES := { "Spine": 0.1, "Chest": 0.15, "UpperChest": 0.15, "Neck": 0.25, "Head": 0.35 }
const FLAIL_BONES := { "LeftUpperArm": 2.2, "RightUpperArm": 2.2, "LeftLowerArm": 0.9, "RightLowerArm": 0.9 }

## Head and torso snap back, arms fling out. Rotation is applied in skeleton space about the side-view axis (X).
static func _exaggerate(skel: Skeleton3D, k: float, heavy: bool) -> void:
	if k <= 0.001: return
	var amt := deg_to_rad(52.0 if heavy else 38.0) * k
	for table in [SNAP_BONES, FLAIL_BONES]:
		var sign_ := -1.0 if table == SNAP_BONES else 1.0
		for bn in table:
			var b := skel.find_bone(bn)
			if b < 0: continue
			var par := skel.get_bone_parent(b)
			var pq := skel.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
			var r := Quaternion(Vector3.RIGHT, sign_ * amt * float(table[bn]))
			skel.set_bone_pose_rotation(b, pq.inverse() * r * pq * skel.get_bone_pose_rotation(b))

## How far the whole body must drop so the lowest bone rests just above the floor (lying and KO poses).
static func _ground_drop(skel: Skeleton3D) -> float:
	var low := 1e9
	for n in BODY_BONES:
		for side in ["Left", "Right"]:
			var b := skel.find_bone(side + n)
			if b >= 0: low = minf(low, skel.get_bone_global_pose(b).origin.y)
	for n in ["Hips", "Spine", "Chest", "Head"]:
		var b := skel.find_bone(n)
		if b >= 0: low = minf(low, skel.get_bone_global_pose(b).origin.y)
	return -(low - 0.07)

## Attaches the accessories listed in fighters/<id>/look.json ("accessories": prop scene, humanoid bone, offset) to the skeleton.
static func dress(skel: Skeleton3D, model_id: String) -> void:
	var path := "res://fighters/%s/look.json" % model_id
	if not FileAccess.file_exists(path): return
	var look: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for acc in look.get("accessories", []):
		var b := skel.find_bone(acc.bone)
		if b < 0: continue
		var att := BoneAttachment3D.new()
		att.bone_name = acc.bone
		skel.add_child(att)
		var prop: Node3D = (load("res://fighters/shared/props/%s.tscn" % acc.prop) as PackedScene).instantiate()
		var p: Array = acc.get("pos", [0, 0, 0]); var r: Array = acc.get("rot", [0, 0, 0]); var sc: Array = acc.get("scale", [1, 1, 1])
		# offsets are authored in T-pose model space; convert through the bone's rest frame so any rig orientation works
		var rb := skel.get_bone_global_rest(b).basis.orthonormalized()
		prop.position = rb.inverse() * Vector3(p[0], p[1], p[2])
		prop.basis = rb.inverse() * Basis.from_euler(Vector3(deg_to_rad(r[0]), deg_to_rad(r[1]), deg_to_rad(r[2]))) * Basis.from_scale(Vector3(sc[0], sc[1], sc[2]))
		att.add_child(prop)
