extends Node3D
## Pose authoring contact sheet: renders key poses side by side with the fight camera's lens, feet snapped to the floor.
## godot --path . res://tools/pose_sheet.tscn -- --out=<png> --list=L:ant,L:imp,2L:imp [--cols=6] [--model=a0] [--w=1600]
## A list item is <pose>:<ant|imp|fol|rec>; "walk" style items are not posed, only names from data/poses.json.
const SPACING := 1.5

func _ready() -> void:
	var out := "pose_sheet.png"; var items := []; var cols := 6; var mid := "a0"; var w := 1600
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--list="): items = a.trim_prefix("--list=").split(",")
		elif a.begins_with("--cols="): cols = int(a.trim_prefix("--cols="))
		elif a.begins_with("--model="): mid = a.trim_prefix("--model=")
		elif a.begins_with("--w="): w = int(a.trim_prefix("--w="))
	var rows := int(ceil(items.size() / float(cols)))
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(w, int(w * rows * 2.2 / (cols * SPACING)))
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("2a1d3e")
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var scene := load("res://fighters/%s/model.scn" % mid) as PackedScene
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://fighters/shared/clip_meta.json"))
	var lib := load("res://fighters/shared/anims.res")
	for i in items.size():
		var parts: PackedStringArray = items[i].split(":")
		var m: Node3D = scene.instantiate()
		m.rotation.y = deg_to_rad(90.0)
		add_child(m)
		var sk: Skeleton3D = m.get_node("Skeleton3D")
		FighterView.dress(sk, mid)
		var ap := AnimationPlayer.new(); m.add_child(ap)
		ap.root_node = ap.get_path_to(m); ap.add_animation_library("", lib)
		var b: Array = PoseLib.base(parts[0])
		ap.play(b[0]); ap.seek(b[1], true); ap.pause(); ap.advance(0.0)
		PoseLib.apply(sk, PoseLib.key(parts[0], parts[1] if parts.size() > 1 else "imp"))
		sk.force_update_all_bone_transforms() if sk.has_method("force_update_all_bone_transforms") else null
		var col := i % cols; var row := i / cols
		m.position = Vector3((col - (cols - 1) * 0.5) * SPACING, -row * 2.2 + PoseLib.floor_drop(sk), 0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows * 2.2
	cam.position = Vector3(0, -(rows - 1) * 1.1 + 0.9, 10)
	add_child(cam)
	var fl := MeshInstance3D.new()
	for r in rows:
		var p := PlaneMesh.new(); p.size = Vector2(cols * SPACING, 0.5)
		var f := MeshInstance3D.new(); f.mesh = p; f.rotation.x = deg_to_rad(90); f.position = Vector3(0, -r * 2.2 - 0.0, -0.4)
		var mt := StandardMaterial3D.new(); mt.albedo_color = Color("4a3868"); mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		f.material_override = mt; add_child(f)
	await get_tree().process_frame; await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
