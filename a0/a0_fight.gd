extends Node3D
## A0 gate scene: the real MatchSim drives two baked 3D fighters in a side view with a fixed camera.
## Keys: see Controls (P1 left, P2 right). R restarts, F2 toggles boxes.
## User args: --shot=<png> [--ticks=N] saves a frame after N scripted ticks and quits; --script plays the demo script live.
const BUTTONS := { "light": SimConst.L, "medium": SimConst.M, "heavy": SimConst.H, "special": SimConst.S, "block": SimConst.BL, "throw": SimConst.THROW }
const W := FighterView.WORLD_PER_PX
const CX := FighterView.CENTER_X

var match_sim: MatchSim
var views: Array[FighterView] = []
var cam: Camera3D
var info: Label
var banner: Label
var timer_label: Label
var hint: Label
var bars: Array[ProgressBar] = []
var model_ids := ["a0", "a0"]
var seq_dir := ""
var seq_every := 3
var seq_from := 0
var shot := ""
var shot_ticks := 0
var script_mode := false
var show_boxes := false
var box_mesh: MeshInstance3D
var _script_t := 0
var _done := false
var shake := 0.0   # camera shake amplitude in metres, kicked by hit/block events and decayed per tick

func _ready() -> void:
	var win := get_window()
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.trim_prefix("--shot=")
		elif a.begins_with("--ticks="): shot_ticks = int(a.trim_prefix("--ticks="))
		elif a == "--script": script_mode = true
		elif a.begins_with("--seq="): seq_dir = a.trim_prefix("--seq=")
		elif a.begins_with("--every="): seq_every = int(a.trim_prefix("--every="))
		elif a.begins_with("--from="): seq_from = int(a.trim_prefix("--from="))
		elif a.begins_with("--p1="): model_ids[0] = a.trim_prefix("--p1=")
		elif a.begins_with("--p2="): model_ids[1] = a.trim_prefix("--p2=")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a1d3e")
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	_build_stage()
	cam = Camera3D.new()
	cam.fov = 21.0
	add_child(cam)
	_reset()
	_build_hud()
	box_mesh = MeshInstance3D.new()
	box_mesh.mesh = ImmediateMesh.new()
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.no_depth_test = true
	box_mesh.material_override = bm
	add_child(box_mesh)

func _reset() -> void:
	match_sim = MatchSim.new("placeholder", "placeholder", 1, 3)
	for v in views: v.queue_free()
	views.clear()
	var swaps := [0.0, 1.0 if model_ids[0] == model_ids[1] else 0.0]   # same model on both sides: P2 gets the hue swap
	for i in 2:
		var v := FighterView.new()
		add_child(v)
		v.setup(match_sim.world.fighters[i], model_ids[i], swaps[i])
		views.append(v)
	_script_t = 0
	_cam_follow(true)

func _build_stage() -> void:
	add_child(AirshipDeck.new())

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = HudTheme.build()
	layer.add_child(root)
	for i in 2:
		var bar := ProgressBar.new(); bar.show_percentage = false
		bar.min_value = 0.0; bar.max_value = 1.0; bar.value = 1.0
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		bar.position = Vector2(40, 28) if i == 0 else Vector2(1280 - 40 - 520, 28); bar.size = Vector2(520, 26)
		root.add_child(bar); bars.append(bar)
	timer_label = _label(root, Vector2(600, 20), "HudTimer")
	timer_label.size = Vector2(80, 50); timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner = _label(root, Vector2(0, 250), "HudBanner")
	banner.size = Vector2(1280, 100); banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info = _label(root, Vector2(40, 64), "HudInfo")
	hint = _label(root, Vector2(40, 690), "HudHint")
	hint.text = "P1 %s | F2 boxes | R restart" % Controls.describe("p1")

func _label(parent: Node, pos: Vector2, variation: String) -> Label:
	var l := Label.new(); l.position = pos
	l.theme_type_variation = variation
	parent.add_child(l)
	return l

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F2: show_boxes = not show_boxes
		elif e.physical_keycode == KEY_R: _reset()

func _read(p: String) -> Dictionary:
	var i := WorldSim.neutral()
	i.left = Input.is_action_pressed(p + "_left"); i.right = Input.is_action_pressed(p + "_right")
	i.up = Input.is_action_pressed(p + "_up"); i.down = Input.is_action_pressed(p + "_down")
	for b in BUTTONS:
		if Input.is_action_pressed(p + "_" + b): i.buttons |= BUTTONS[b]
	return i

## Demo script: P1 walks in, then jabs, crosses, hooks on a loop; P2 throws a jab now and then.
func _scripted() -> Array:
	var a := WorldSim.neutral(); var b := WorldSim.neutral()
	if not match_sim.inputs_live(): return [a, b]
	_script_t += 1
	var fs := match_sim.world.fighters
	var gap := absf(fs[1].x - fs[0].x)
	if gap > 64.0 and _script_t < 400: a.right = true
	else:
		var k := _script_t % 150
		if k == 2: a.buttons = SimConst.L
		elif k == 14: a.buttons = SimConst.M
		elif k == 40: a.buttons = SimConst.H
	if _script_t % 240 == 150: b.buttons = SimConst.L
	return [a, b]

func _tick(dt: float, inputs: Array) -> void:
	match_sim.step(inputs)
	for e in match_sim.world.events:
		match e.type:
			"hit": shake = maxf(shake, clampf(0.02 + float(e.dmg) * 0.0007, 0.02, 0.09))
			"throw": shake = maxf(shake, 0.07)
			"tech": shake = maxf(shake, 0.03)
			"block": shake = maxf(shake, 0.012)
			"ko": shake = maxf(shake, 0.12)
	shake *= 0.84
	for v in views: v.present(dt, match_sim.world.tick)

func _physics_process(dt: float) -> void:
	if _done: return
	if seq_dir != "":
		_done = true
		DirAccess.make_dir_recursive_absolute(seq_dir)
		var n := 0
		for i in shot_ticks:
			_tick(1.0 / 60.0, _scripted())
			if i >= seq_from and (i - seq_from) % seq_every == 0:
				_cam_follow(true)
				_hud()
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/f%03d.png" % [seq_dir, n])
				n += 1
		get_tree().quit()
		return
	if shot != "":
		_done = true
		for i in shot_ticks: _tick(1.0 / 60.0, _scripted())
		_cam_follow(true)
		_hud()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_hud()
		print("HUD: ", info.text)
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()
		return
	_tick(dt, _scripted() if script_mode else [_read("p1"), _read("p2")])
	_cam_follow(false)
	_hud()
	_draw_boxes()

func _cam_follow(snap: bool) -> void:
	var fs := match_sim.world.fighters
	var mid := ((fs[0].x + fs[1].x) * 0.5 - CX) * W
	var sep := absf(fs[1].x - fs[0].x) * W
	var dist := clampf(10.2 + maxf(sep - 3.2, 0.0) * 0.6, 10.2, 14.0)
	var target := Vector3(AirshipDeck.clamp_camera_x(mid, dist), 1.05, dist)
	cam.position = target if snap else cam.position.lerp(target, 0.12)
	if shake > 0.002:
		var t := float(match_sim.world.tick)
		cam.position += Vector3(sin(t * 12.9898), cos(t * 78.233), 0.0) * shake

func _hud() -> void:
	var fs := match_sim.world.fighters
	for i in 2:
		var pct := clampf(float(fs[i].hp) / float(fs[i].stats.hp), 0.0, 1.0)
		bars[i].value = pct
		bars[i].theme_type_variation = "" if pct > 0.3 else "HealthLow"
	timer_label.text = "%02d" % match_sim.seconds_left()
	banner.text = _banner()
	info.text = "P1 %s | P2 %s | combo %d | %d fps | %s | %d draws" % [fs[0].anim(), fs[1].anim(), fs[1].combo_hits, Engine.get_frames_per_second(), RenderingServer.get_current_rendering_method(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]

func _banner() -> String:
	match match_sim.phase:
		"call": return "ROUND %d" % match_sim.round_no
		"fight": return "FIGHT!"
		"ko": return "K.O."
		"timeup": return "TIME UP"
		"over": return "DRAW" if match_sim.match_winner < 0 else "P%d WINS" % (match_sim.match_winner + 1)
	return ""

func _draw_boxes() -> void:
	var im: ImmediateMesh = box_mesh.mesh
	im.clear_surfaces()
	if not show_boxes: return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for f in match_sim.world.fighters:
		for h in f.hurt_boxes(): _rect(im, h, Color("41e07a"))
		_rect(im, f.push_box(), Color("4da3ff"))
		for ah in f.active_hits(): _rect(im, f.hit_rect(ah[1]), Color("ff4a4a"))
	im.surface_end()

func _rect(im: ImmediateMesh, r: Rect2, c: Color) -> void:
	var x0 := (r.position.x - CX) * W; var x1 := (r.end.x - CX) * W
	var y0 := r.position.y * W; var y1 := r.end.y * W
	var pts := [Vector3(x0, y0, 0.4), Vector3(x1, y0, 0.4), Vector3(x1, y1, 0.4), Vector3(x0, y1, 0.4)]
	for i in 4:
		im.surface_set_color(c); im.surface_add_vertex(pts[i])
		im.surface_set_color(c); im.surface_add_vertex(pts[(i + 1) % 4])
