extends SceneTree
## godot --headless --path . -s tools/measure_walk.gd : foot travel of the Walk clip (skeleton space, metres) per cycle.
func _init() -> void:
	await _run()

func _run() -> void:
	var m: Node3D = (load("res://fighters/a0/model.scn") as PackedScene).instantiate()
	root.add_child(m)
	var sk: Skeleton3D = m.get_node("Skeleton3D")
	var ap := AnimationPlayer.new(); m.add_child(ap)
	ap.root_node = ap.get_path_to(m); ap.add_animation_library("", load("res://fighters/shared/anims.res"))
	var len := ap.get_animation("Walk").length
	print("walk length ", len)
	var n := 24
	var prev := {}
	var fastest := {"LeftFoot": 0.0, "RightFoot": 0.0}
	var floor_t := {"LeftFoot": [], "RightFoot": []}
	for i in n + 1:
		ap.play("Walk"); ap.seek(len * i / float(n), true); ap.pause(); ap.advance(0.0); await process_frame
		for nm in ["LeftFoot", "RightFoot"]:
			var p := sk.get_bone_global_pose(sk.find_bone(nm)).origin
			floor_t[nm].append(p)
	for nm in floor_t:
		var lo := 1e9
		for p in floor_t[nm]: lo = minf(lo, p.y)
		var speeds := []
		for i in n:
			var a: Vector3 = floor_t[nm][i]; var b: Vector3 = floor_t[nm][i + 1]
			if a.y < lo + 0.05 and b.y < lo + 0.05: speeds.append((b.z - a.z) / (len / n))
		print(nm, " stance speeds z m/s: ", speeds)
	quit()
