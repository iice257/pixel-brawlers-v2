extends SceneTree
## Retargets Quaternius UAL clips onto the baked VRM skeleton (humanoid bone names) and saves an AnimationLibrary.
## Global-orientation retarget: delta = anim_global * src_rest_global^-1, target_global = delta * tgt_rest_global.
## Run: godot --headless --path . --script res://tools/a0_bake_anims.gd

const OUT := "res://fighters/shared/anims.res"
const SRC := {
	"res://assets/src/anim/UAL1_Standard.glb": ["Idle", "Walk", "Crouch_Idle", "Crouch_Fwd", "Punch_Jab", "Punch_Cross", "Hit_Chest", "Hit_Head", "Death01", "Jump_Start", "Jump", "Jump_Land", "Roll", "Sword_Attack"],
	"res://assets/src/anim/UAL2_Standard.glb": ["Melee_Hook", "Melee_Hook_Rec", "Hit_Knockback", "Sword_Block", "LayToIdle", "Idle_Shield_Loop", "Shield_Dash", "OverhandThrow"],
}
const FPS := 30.0

# UAL bone -> VRM humanoid bone
static func bone_map() -> Dictionary:
	var m := {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Chest", "spine_03": "UpperChest", "neck_01": "Neck", "Head": "Head"}
	for side in [["l", "Left"], ["r", "Right"]]:
		var s: String = side[0]; var S: String = side[1]
		m["clavicle_" + s] = S + "Shoulder"; m["upperarm_" + s] = S + "UpperArm"; m["lowerarm_" + s] = S + "LowerArm"; m["hand_" + s] = S + "Hand"
		m["thigh_" + s] = S + "UpperLeg"; m["calf_" + s] = S + "LowerLeg"; m["foot_" + s] = S + "Foot"; m["ball_" + s] = S + "Toes"
		for f in [["index", "Index"], ["middle", "Middle"], ["ring", "Ring"], ["pinky", "Little"]]:
			m["%s_01_%s" % [f[0], s]] = "%s%sProximal" % [S, f[1]]
			m["%s_02_%s" % [f[0], s]] = "%s%sIntermediate" % [S, f[1]]
			m["%s_03_%s" % [f[0], s]] = "%s%sDistal" % [S, f[1]]
		m["thumb_01_" + s] = S + "ThumbMetacarpal"; m["thumb_02_" + s] = S + "ThumbProximal"; m["thumb_03_" + s] = S + "ThumbDistal"
	return m

func _init() -> void:
	print("start")
	var tgt_scene: Node = (load("res://fighters/a0/model.scn") as PackedScene).instantiate()
	root.add_child(tgt_scene)
	var tgt: Skeleton3D = tgt_scene.get_node("Skeleton3D")
	var map := bone_map()
	var lib := AnimationLibrary.new()
	for path in SRC:
		var inst: Node = (load(path) as PackedScene).instantiate()
		root.add_child(inst)
		print("loaded ", path)
		var src: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var ctx := _context(src, tgt, map)
		for name in SRC[path]:
			var key := _find_anim(ap, name)
			if key == "": push_error("missing clip " + name); continue
			var out := _retarget(ap.get_animation(key), src, tgt, map, ctx)
			lib.add_animation(name, out)
			print("  ", name, " ", snappedf(out.length, 0.01), "s tracks=", out.get_track_count())
	print("saved ", OUT, " err=", ResourceSaver.save(lib, OUT))
	quit()

func _find_anim(ap: AnimationPlayer, name: String) -> String:
	for n in ap.get_animation_list():
		if n == name or n == name + "_Loop": return n
	return ""

func _context(src: Skeleton3D, tgt: Skeleton3D, map: Dictionary) -> Dictionary:
	var src_g := []   # global rest rotations
	for i in src.get_bone_count(): src_g.append(src.get_bone_global_rest(i).basis.get_rotation_quaternion())
	var tgt_g := []
	for i in tgt.get_bone_count(): tgt_g.append(tgt.get_bone_global_rest(i).basis.get_rotation_quaternion())
	var hips_t := tgt.find_bone("Hips"); var pel_s := src.find_bone("pelvis")
	var scale := tgt.get_bone_global_rest(hips_t).origin.y / maxf(src.get_bone_global_rest(pel_s).origin.y, 0.001)
	return {"src_g": src_g, "tgt_g": tgt_g, "scale": scale}

func _retarget(a: Animation, src: Skeleton3D, tgt: Skeleton3D, map: Dictionary, ctx: Dictionary) -> Animation:
	# per-source-bone tracks (rotation, position) by bone name
	var rot_tr := {}; var pos_tr := {}
	for t in a.get_track_count():
		var p := str(a.track_get_path(t)); var bn := p.get_slice(":", 1)
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D: rot_tr[bn] = t
		elif a.track_get_type(t) == Animation.TYPE_POSITION_3D: pos_tr[bn] = t
	var out := Animation.new()
	out.length = a.length
	out.loop_mode = a.loop_mode
	out.step = 1.0 / FPS
	var tgt_names := {}   # target bone idx -> source bone idx
	for sb in map:
		var si := src.find_bone(sb); var ti := tgt.find_bone(map[sb])
		if si >= 0 and ti >= 0: tgt_names[ti] = si
	var rot_out := {}; var pos_out := -1
	for ti in tgt_names:
		var idx := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(idx, NodePath("Skeleton3D:" + tgt.get_bone_name(ti)))
		rot_out[ti] = idx
	pos_out = out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(pos_out, NodePath("Skeleton3D:Hips"))
	var frames := int(ceil(a.length * FPS)) + 1
	var src_g: Array = ctx.src_g; var tgt_g: Array = ctx.tgt_g
	var src_order := _order(src); var tgt_order := _order(tgt)
	for f in frames:
		var t := minf(f / FPS, a.length)
		# source global animated orientations, root-first (bone indices are parent-before-child in glTF skeletons)
		var ga := []
		ga.resize(src.get_bone_count())
		for i in src_order:
			var bn := src.get_bone_name(i)
			var q: Quaternion = src.get_bone_rest(i).basis.get_rotation_quaternion()
			if rot_tr.has(bn): q = a.rotation_track_interpolate(rot_tr[bn], t)
			var par := src.get_bone_parent(i)
			ga[i] = q if par < 0 else (ga[par] as Quaternion) * q
		var gt := []
		gt.resize(tgt.get_bone_count())
		for i in tgt_order:
			var par := tgt.get_bone_parent(i)
			var g: Quaternion
			if tgt_names.has(i):
				var si: int = tgt_names[i]
				var delta: Quaternion = (ga[si] as Quaternion) * (src_g[si] as Quaternion).inverse()
				g = delta * (tgt_g[i] as Quaternion)
			else:
				var rest_local := tgt.get_bone_rest(i).basis.get_rotation_quaternion()
				g = rest_local if par < 0 else (gt[par] as Quaternion) * rest_local
			gt[i] = g
			if tgt_names.has(i):
				var local: Quaternion = g if par < 0 else (gt[par] as Quaternion).inverse() * g
				out.rotation_track_insert_key(rot_out[i], t, local.normalized())
		# hips translation: rest + scaled source displacement (vertical keeps its offset from rest)
		var hips := tgt.find_bone("Hips"); var pel := src.find_bone("pelvis")
		var rest_t := tgt.get_bone_rest(hips).origin
		var p_s := src.get_bone_rest(pel).origin
		if pos_tr.has("pelvis"): p_s = a.position_track_interpolate(pos_tr["pelvis"], t)
		var d := (p_s - src.get_bone_rest(pel).origin) * float(ctx.scale)
		d.x = 0.0; d.z = 0.0   # clips are played in place; the sim owns horizontal motion
		out.position_track_insert_key(pos_out, t, rest_t + d)
	return out

## Bone indices with every parent before its children (glTF/VRM skeletons do not guarantee index order).
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
