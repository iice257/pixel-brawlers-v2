extends SceneTree
## Measures each baked clip: length and the time of maximum reach (hand or foot farthest from the hips, horizontally).
## The presenter uses peak_t as the impact pose. Pure FK over the animation tracks, so it runs headless.
## Run: godot --headless --path . --script res://tools/a0_clip_meta.gd
func _init() -> void:
	var m: Node3D = (load("res://fighters/a0/model.scn") as PackedScene).instantiate()
	root.add_child(m)
	var sk: Skeleton3D = m.get_node("Skeleton3D")
	var lib: AnimationLibrary = load("res://fighters/shared/anims.res")
	var order := _order(sk)
	var ends := ["LeftHand", "RightHand", "LeftFoot", "RightFoot"].map(func(n): return sk.find_bone(n))
	var hips := sk.find_bone("Hips")
	var meta := {}
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		var rot := {}
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rot[sk.find_bone(str(a.track_get_path(t)).get_slice(":", 1))] = t
		var best := 0.0; var best_t := 0.0; var t := 0.0
		while t <= a.length + 0.0001:
			var g := {}
			for i in order:
				var q := sk.get_bone_rest(i).basis.get_rotation_quaternion()
				if rot.has(i): q = a.rotation_track_interpolate(rot[i], t)
				var local := Transform3D(Basis(q), sk.get_bone_rest(i).origin)
				var p := sk.get_bone_parent(i)
				g[i] = local if p < 0 else (g[p] as Transform3D) * local
			var h: Vector3 = (g[hips] as Transform3D).origin
			for e in ends:
				var d: float = absf((g[e] as Transform3D).origin.z - h.z)
				if d > best: best = d; best_t = t
			t += 1.0 / 60.0
		meta[n] = {"length": snappedf(a.length, 0.001), "peak_t": snappedf(best_t, 0.001), "reach": snappedf(best, 0.001)}
	var f := FileAccess.open("res://fighters/shared/clip_meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  ", true)); f.close()
	print(JSON.stringify(meta))
	quit()

func _order(sk: Skeleton3D) -> Array:
	var out := []; var seen := {}
	for i in sk.get_bone_count():
		var chain := []; var b := i
		while b >= 0 and not seen.has(b):
			chain.push_front(b); b = sk.get_bone_parent(b)
		for c in chain: seen[c] = true; out.append(c)
	return out
