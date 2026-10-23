extends SceneTree
## Retargets the MocapOnline (MotusMan) FBX clips in assets/src/mco onto the baked VRM skeleton and saves assets/anims/ext.res.
## Same global-orientation retarget as a0_bake_anims.gd; clips are baked in place (hips keep only their vertical motion).
## Prints each clip's planted-foot speed in m/s on our rig: that is the "mps" value data/anim_map.json uses for stride-scaled playback.
## Run: godot --headless --path . --script res://tools/bake_mco.gd
const Bake := preload("res://tools/a0_bake_anims.gd")

const OUT := "res://assets/anims/ext.res"
const DIR := "res://assets/src/mco/"
const FPS := 30.0
## MotusMan rests in an A-pose, our model in a T-pose, so orientation deltas alone leave the arms near T. Each bone is also swung so its direction
## to this child bone matches the source's animated direction (twist stays from the orientation delta).
const CHILD := {"Hips": "Spine", "Spine": "Chest", "Chest": "UpperChest", "UpperChest": "Neck", "Neck": "Head",
	"LeftShoulder": "LeftUpperArm", "LeftUpperArm": "LeftLowerArm", "LeftLowerArm": "LeftHand", "LeftHand": "LeftMiddleProximal",
	"RightShoulder": "RightUpperArm", "RightUpperArm": "RightLowerArm", "RightLowerArm": "RightHand", "RightHand": "RightMiddleProximal",
	"LeftUpperLeg": "LeftLowerLeg", "LeftLowerLeg": "LeftFoot", "LeftFoot": "LeftToes",
	"RightUpperLeg": "RightLowerLeg", "RightLowerLeg": "RightFoot", "RightFoot": "RightToes"}
# clip name in ext.res -> [fbx, loops]
# clip -> [fbx, loops, fighting stance: yaw/tilt locked and the keyed guard layered over the arms]
const CLIPS := {
	"Fight_Idle": ["MOB1_Stand_Relaxed_Fgt_v1", true, true],
	"Idle": ["MOB1_Stand_Relaxed_Idle_v2", true, true],
	"Walk_F": ["MOB1_Walk_F", true, true],
	"Jog_F": ["MOB1_Jog_F", true, true],
	"Crouch_Walk_F": ["MOB1_CrouchWalk_F", true, true],
	"Idle_To_Walk": ["MOB1_Stand_Relaxed_to_Walk_F", false, true],
	"Roll_F": ["Ninja1_Combat_Forward_Roll_v1", false, false],
}
## A fighter stays side-on to the opponent: the hips may yaw this far off the facing axis, each spine bone and the head a little more (degrees).
## Tilt is the lean from vertical: a fighting crouch keeps the torso up and the head looking at the opponent.
const LIMITS := {"Hips": {"yaw": 8.0}, "Spine": {"yaw": 12.0, "tilt": 20.0}, "Chest": {"yaw": 14.0, "tilt": 22.0},
	"UpperChest": {"yaw": 15.0, "tilt": 24.0}, "Neck": {"yaw": 20.0, "tilt": 22.0}, "Head": {"yaw": 22.0, "tilt": 18.0}}
const GUARD_CLIP := "Punch_Jab"   # the keyed boxing guard (fighters/shared/anims.res) at t=0: arms and fingers come from here
const ARM_WORDS := ["Shoulder", "UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little"]

func _init() -> void:
	var tgt_scene: Node = (load("res://fighters/a0/model.scn") as PackedScene).instantiate()
	root.add_child(tgt_scene)
	var tgt: Skeleton3D = tgt_scene.get_node("Skeleton3D")
	var map := Bake.bone_map()
	map["head"] = "Head"
	var lib := AnimationLibrary.new()
	for name in CLIPS:
		var inst: Node = (load(DIR + CLIPS[name][0] + ".fbx") as PackedScene).instantiate()
		root.add_child(inst)
		var src: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var a := ap.get_animation(ap.get_animation_list()[0])
		var ctx := _context(src, tgt)
		ctx["stance"] = CLIPS[name][2]
		var out := _retarget(a, src, tgt, map, ctx)
		out.loop_mode = Animation.LOOP_LINEAR if CLIPS[name][1] else Animation.LOOP_NONE
		lib.add_animation(name, out)
		var st := _stance_speed(a, src)
		print(name, " ", snappedf(out.length, 0.01), "s  planted-foot ", snappedf(float(st[0]) * float(ctx.scale), 0.001), " m/s  pelvis travel ", snappedf(float(st[1]) * float(ctx.scale), 0.001), " m")
		inst.queue_free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/anims"))
	print("saved ", OUT, " err=", ResourceSaver.save(lib, OUT))
	quit()

func _context(src: Skeleton3D, tgt: Skeleton3D) -> Dictionary:
	var src_g := []
	for i in src.get_bone_count(): src_g.append(src.get_bone_global_rest(i).basis.get_rotation_quaternion())
	var tgt_g := []
	for i in tgt.get_bone_count(): tgt_g.append(tgt.get_bone_global_rest(i).basis.get_rotation_quaternion())
	var scale := tgt.get_bone_global_rest(tgt.find_bone("Hips")).origin.y / maxf(src.get_bone_global_rest(src.find_bone("pelvis")).origin.y, 0.001)
	return {"src_g": src_g, "tgt_g": tgt_g, "scale": scale}

## Median horizontal speed of whichever foot is lower, over the clip (source metres per second), by forward kinematics on the clip's own tracks.
## Also returns the pelvis's horizontal travel so a clip that is not in place shows up in the log.
func _stance_speed(a: Animation, src: Skeleton3D) -> Array:
	var rot_tr := {}; var pos_tr := {}
	for t in a.get_track_count():
		var bn := str(a.track_get_path(t)).get_slice(":", 1)
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D: rot_tr[bn] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D: pos_tr[bn] = t
	var order := _order(src)
	var fl := src.find_bone("foot_l"); var fr := src.find_bone("foot_r"); var pel := src.find_bone("pelvis")
	var prev := Vector3.ZERO; var prev_low := -1
	var speeds: Array = []
	var pel_min := Vector2(1e9, 1e9); var pel_max := Vector2(-1e9, -1e9)
	for f in int(a.length * FPS) + 1:
		var t := minf(f / FPS, a.length)
		var g := []; g.resize(src.get_bone_count())
		for i in order:
			var bn := src.get_bone_name(i)
			var rest := src.get_bone_rest(i)
			var q: Quaternion = rest.basis.get_rotation_quaternion()
			if rot_tr.has(bn): q = a.rotation_track_interpolate(rot_tr[bn], t)
			var o := rest.origin
			if i == pel and pos_tr.has(bn): o = a.position_track_interpolate(pos_tr[bn], t)
			var local := Transform3D(Basis(q), o)
			var par := src.get_bone_parent(i)
			g[i] = local if par < 0 else (g[par] as Transform3D) * local
		var pp: Vector3 = (g[pel] as Transform3D).origin
		pel_min = Vector2(minf(pel_min.x, pp.x), minf(pel_min.y, pp.z)); pel_max = Vector2(maxf(pel_max.x, pp.x), maxf(pel_max.y, pp.z))
		var pl: Vector3 = (g[fl] as Transform3D).origin; var pr: Vector3 = (g[fr] as Transform3D).origin
		var low := 0 if pl.y < pr.y else 1
		var p := pl if low == 0 else pr
		if f > 0 and low == prev_low: speeds.append(Vector2(p.x - prev.x, p.z - prev.z).length() * FPS)
		prev = p; prev_low = low
	if speeds.is_empty(): return [0.0, 0.0]
	speeds.sort()
	return [float(speeds[speeds.size() / 2]), (pel_max - pel_min).length()]

func _retarget(a: Animation, src: Skeleton3D, tgt: Skeleton3D, map: Dictionary, ctx: Dictionary) -> Animation:
	var rot_tr := {}; var pos_tr := {}
	for t in a.get_track_count():
		var bn := str(a.track_get_path(t)).get_slice(":", 1)
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D: rot_tr[bn] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D: pos_tr[bn] = t
	var out := Animation.new()
	out.length = a.length
	out.step = 1.0 / FPS
	var tgt_names := {}
	for sb in map:
		var si := src.find_bone(sb); var ti := tgt.find_bone(map[sb])
		if si >= 0 and ti >= 0: tgt_names[ti] = si
	var rot_out := {}
	for ti in tgt_names:
		var idx := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(idx, NodePath("Skeleton3D:" + tgt.get_bone_name(ti)))
		rot_out[ti] = idx
	var pos_out := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(pos_out, NodePath("Skeleton3D:Hips"))
	var src_g: Array = ctx.src_g; var tgt_g: Array = ctx.tgt_g
	var stance: bool = ctx.stance
	var guard := _guard_locals(tgt)
	var src_order := _order(src); var tgt_order := _order(tgt)
	var hips := tgt.find_bone("Hips"); var pel := src.find_bone("pelvis")
	var rest_t := tgt.get_bone_rest(hips).origin
	var rest_p := src.get_bone_rest(pel).origin
	for f in int(ceil(a.length * FPS)) + 1:
		var t := minf(f / FPS, a.length)
		var ga := []; ga.resize(src.get_bone_count())
		for i in src_order:
			var bn := src.get_bone_name(i)
			var q: Quaternion = src.get_bone_rest(i).basis.get_rotation_quaternion()
			if rot_tr.has(bn): q = a.rotation_track_interpolate(rot_tr[bn], t)
			var par := src.get_bone_parent(i)
			ga[i] = q if par < 0 else (ga[par] as Quaternion) * q
		var pa := []; pa.resize(src.get_bone_count())   # source animated global positions
		for i in src_order:
			var par := src.get_bone_parent(i)
			var o := src.get_bone_rest(i).origin
			if i == pel and pos_tr.has("pelvis"): o = a.position_track_interpolate(pos_tr["pelvis"], t)
			pa[i] = o if par < 0 else (pa[par] as Vector3) + (ga[par] as Quaternion) * o
		var gt := []; gt.resize(tgt.get_bone_count())
		var corr := []; corr.resize(tgt.get_bone_count())   # global-frame correction already applied to a bone and inherited by its children
		for i in tgt_order:
			var par := tgt.get_bone_parent(i)
			var g: Quaternion
			var nm := tgt.get_bone_name(i)
			var layered := stance and guard.has(nm) and par >= 0
			corr[i] = Quaternion.IDENTITY if par < 0 else corr[par]
			if layered:
				g = (gt[par] as Quaternion) * (guard[nm] as Quaternion)
			elif tgt_names.has(i):
				var si: int = tgt_names[i]
				g = ((ga[si] as Quaternion) * (src_g[si] as Quaternion).inverse()) * (tgt_g[i] as Quaternion)
				var cn: String = CHILD.get(tgt.get_bone_name(i), "")
				var ci := tgt.find_bone(cn) if cn != "" else -1
				if ci >= 0 and tgt_names.has(ci):
					var sci: int = tgt_names[ci]
					var want: Vector3 = (pa[sci] as Vector3) - (pa[si] as Vector3)
					var rest_dir: Vector3 = tgt.get_bone_global_rest(ci).origin - tgt.get_bone_global_rest(i).origin
					var have: Vector3 = g * ((tgt_g[i] as Quaternion).inverse() * rest_dir)
					if want.length() > 1e-5 and have.length() > 1e-5:
						g = _swing(have.normalized(), want.normalized()) * g
			else:
				var rest_local := tgt.get_bone_rest(i).basis.get_rotation_quaternion()
				g = rest_local if par < 0 else (gt[par] as Quaternion) * rest_local
			if not layered:
				g = (corr[i] as Quaternion) * g
				if stance and LIMITS.has(nm):
					var fix := _limit(g, tgt_g[i] as Quaternion, LIMITS[nm])
					g = fix * g
					corr[i] = fix * (corr[i] as Quaternion)
			gt[i] = g
			if tgt_names.has(i):
				var local: Quaternion = g if par < 0 else (gt[par] as Quaternion).inverse() * g
				out.rotation_track_insert_key(rot_out[i], t, local.normalized())
		var p_s := rest_p
		if pos_tr.has("pelvis"): p_s = a.position_track_interpolate(pos_tr["pelvis"], t)
		var d := (p_s - rest_p) * float(ctx.scale)
		d.x = 0.0; d.z = 0.0
		out.position_track_insert_key(pos_out, t, rest_t + d)
	return out

## Bone indices with every parent before its children.
func _order(sk: Skeleton3D) -> Array:
	var out := []
	var seen := {}
	for i in sk.get_bone_count():
		var chain := []
		var b := i
		while b >= 0 and not seen.has(b):
			chain.push_front(b); b = sk.get_bone_parent(b)
		for c in chain: seen[c] = true; out.append(c)
	return out

## Shortest rotation taking unit vector a onto unit vector b.
func _swing(a: Vector3, b: Vector3) -> Quaternion:
	var d := a.dot(b)
	if d > 0.99999: return Quaternion.IDENTITY
	if d < -0.99999:
		var ax := a.cross(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).normalized()
		return Quaternion(ax, PI)
	return Quaternion(a.cross(b).normalized(), acos(clampf(d, -1.0, 1.0)))

## Local rotations of the arm and finger bones in the keyed guard pose.
func _guard_locals(tgt: Skeleton3D) -> Dictionary:
	var a: Animation = (load("res://fighters/shared/anims.res") as AnimationLibrary).get_animation(GUARD_CLIP)
	var out := {}
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D: continue
		var bn := str(a.track_get_path(t)).get_slice(":", 1)
		for w in ARM_WORDS:
			if bn.contains(w): out[bn] = a.rotation_track_interpolate(t, 0.0)
	return out

## The rotation (global frame) that pulls `g` back inside the yaw and tilt limits of its bone. `rest_g` is the bone's rest orientation, facing +Z.
func _limit(g: Quaternion, rest_g: Quaternion, lim: Dictionary) -> Quaternion:
	var out := Quaternion.IDENTITY
	var d := g * rest_g.inverse()
	var fwd := d * Vector3.BACK
	var yaw := atan2(fwd.x, fwd.z)
	var ymax := deg_to_rad(float(lim.yaw))
	var ex := yaw - clampf(yaw, -ymax, ymax)
	if absf(ex) > 1e-5:
		out = Quaternion(Vector3.UP, -ex)
		d = out * d
	if lim.has("tilt"):
		var up := d * Vector3.UP
		var tilt := acos(clampf(up.y, -1.0, 1.0))
		var tmax := deg_to_rad(float(lim.tilt))
		if tilt > tmax + 1e-5 and up.cross(Vector3.UP).length() > 1e-6:
			out = Quaternion(up.cross(Vector3.UP).normalized(), tilt - tmax) * out
	return out
