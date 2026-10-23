extends Node3D
## A0 look test: one baked fighter on a flat floor with the fixed side camera. --shot=<png> saves a frame and quits.
## User args: --shot=<file> --anim=<name> --t=<seconds into the clip> --face=<1|-1> --black (silhouette test) --key=<PoseLib pose> --drop (floor-snap like the fight view); --anim=ext/<clip> plays an imported clip
const WORLD_PER_PX := 0.018   # sim pixels to metres: a 100 px fighter is 1.8 m

var model: Node3D
var cam: Camera3D

func _ready() -> void:
	var shot := ""; var anim := ""; var t := 0.0; var face := 1; var black := false; var hit := 0.0; var heavy := false; var ground := false; var mark := -1; var mid := "a0"; var key := ""; var drop := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.trim_prefix("--shot=")
		elif a.begins_with("--anim="): anim = a.trim_prefix("--anim=")
		elif a.begins_with("--t="): t = float(a.trim_prefix("--t="))
		elif a.begins_with("--face="): face = int(a.trim_prefix("--face="))
		elif a == "--black": black = true
		elif a.begins_with("--model="): mid = a.trim_prefix("--model=")
		elif a.begins_with("--mark="): mark = int(a.trim_prefix("--mark="))
		elif a.begins_with("--hit="): hit = float(a.trim_prefix("--hit="))
		elif a == "--heavy": heavy = true
		elif a == "--ground": ground = true
		elif a.begins_with("--key="): key = a.trim_prefix("--key=")
		elif a == "--drop": drop = true
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a1d3e") if not black else Color.WHITE
	we.environment = env
	add_child(we)
	model = (load("res://fighters/%s/model.scn" % mid) as PackedScene).instantiate()
	model.rotation.y = deg_to_rad(90.0 * face)
	add_child(model)
	FighterView.dress(model.get_node("Skeleton3D"), mid)
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = ap.get_path_to(model)
	ap.add_animation_library("", load("res://fighters/shared/anims.res"))
	if AnimSource.library() != null: ap.add_animation_library("ext", AnimSource.library())
	if anim != "":
		ap.play(anim); ap.seek(t, true); ap.pause(); ap.advance(0.0)
		var sk: Skeleton3D = model.get_node("Skeleton3D")
		if key != "": PoseLib.apply(sk, PoseLib.key(key, ""))
		FighterView._exaggerate(sk, hit, heavy)
		if drop:
			await get_tree().process_frame
			model.position.y = PoseLib.floor_drop(sk)
		if ground:
			await get_tree().process_frame
			model.position.y = FighterView._ground_drop(sk)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(12, 4)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("3a2a52") if not black else Color.WHITE; fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 21.0
	cam.position = Vector3(0, 1.05, 10.2)
	add_child(cam)
	if mark >= 0:
		var m := StandardMaterial3D.new(); m.albedo_color = Color.RED; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		model.get_node("Skeleton3D/Body").set_surface_override_material(mark, m)
	if black: _black_fill(model)
	if shot != "":
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()

func _black_fill(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new(); m.albedo_color = Color.BLACK; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
