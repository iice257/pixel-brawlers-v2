extends SceneTree
## Dev tool: dump skeleton, meshes, materials of an imported model. Usage: godot --headless --script res://tools/a0_inspect.gd -- res://path
func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var n: Node = (load(path) as PackedScene).instantiate()
	root.add_child(n)
	_walk(n, 0)
	quit()

func _walk(n: Node, d: int) -> void:
	var extra := ""
	if n is Skeleton3D: extra = " bones=%d" % n.get_bone_count()
	if n is MeshInstance3D and n.mesh:
		var tris := 0
		for s in n.mesh.get_surface_count(): tris += n.mesh.surface_get_array_len(s) if n.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] == null else n.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
		extra = " surfaces=%d tris=%d" % [n.mesh.get_surface_count(), tris]
		for s in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(s)
			extra += "\n%s    mat[%d]=%s %s" % ["  ".repeat(d), s, m.resource_name if m else "-", m.get_class() if m else ""]
	if n is AnimationPlayer: extra = " anims=%s" % [n.get_animation_list()]
	print("  ".repeat(d), n.name, " <", n.get_class(), ">", extra)
	if n is Skeleton3D and d < 4:
		var names := []
		for i in n.get_bone_count(): names.append(n.get_bone_name(i))
		print("  ".repeat(d), "  bones: ", ", ".join(names))
	for c in n.get_children(): _walk(c, d + 1)
