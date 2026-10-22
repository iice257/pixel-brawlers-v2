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
var hud: FightHud
var hint: Label
var fighter_ids := ["kestrel", "briggs"]   # data/fighters/<id>.json for each side
var model_ids := ["a0", "briggs"]
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
var nudge := 0.0   # sideways camera push on heavy hits (metres, towards the defender), decayed per tick
var env: Environment
var stage: ParallaxStage
var sfx: Sfx.Pool
var sparks: Array = []        # [node, age, life, size]
var spark_mesh: ArrayMesh
const NAMES := ["KESTREL", "BRIGGS"]   # default display names; the front end passes its own through cfg
const DUMMY := ["stand", "crouch", "block all", "random block"]
const TRAINING_HINT := "TRAINING | dummy: %s | Tab cycles it | F2 boxes | F4 inputs | Esc pause"
signal exit(action: String)           # "rematch" | "select" | "menu": the front end decides what comes next
var cfg := {}                         # set by the front end before the node enters the tree: mode (versus | cpu | training), tier, names, models
var names: Array = NAMES
var cpu: CpuBrain
var dummy := 0                        # training dummy behaviour, index into DUMMY
var paused := false
var pause_menu: VBoxContainer
var dummy_btn: Button
var _dummy_t := 0
var _dummy_block := false
var tools: TrainingTools              # training only: input display (F4) and frame advantage
var input_label: Label
var adv_label: Label
var rematch: VBoxContainer
var ko_k := 0.0               # 0..1 how far into the KO slow-mo (palette shift, zoom)
var banner_pivot: Node2D
var help_on := false
var demo_on := false
var stills_dir := ""               # --stills=<dir>: save a frame on big hits (impact flash) for posting
var _stills := 0
var _still_tick := -999
var cpu1: CpuBrain              # --demo: a second CPU drives P1 (capture takes; --seed=N picks the take)
var demo_seed := 11
var p2_hp := 0                # --p2hp=N starts P2 with N hit points (demo recording)
var online := false           # cfg.mode == "online": a RollbackSession over cfg.link drives the match, the local player is link.local_index()
var link: NetLink
var session: RollbackSession
var online_msg := ""          # set when the connection is lost or the peers desync
var touch: TouchControls

func _ready() -> void:
	var win := get_window()
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	online = cfg.get("mode", "") == "online"
	if online: link = cfg.link
	if cfg.has("fighters"): fighter_ids = cfg.fighters.duplicate()
	if cfg.has("names"): names = cfg.names
	else: names = fighter_ids.map(func(i: String) -> String: return String(FighterSim.load_data(i).name))
	if cfg.has("models"): model_ids = cfg.models.duplicate()
	else: model_ids = fighter_ids.map(func(i: String) -> String: return String(FighterSim.load_data(i).model))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.trim_prefix("--shot=")
		elif a.begins_with("--ticks="): shot_ticks = int(a.trim_prefix("--ticks="))
		elif a == "--script": script_mode = true
		elif a.begins_with("--seq="): seq_dir = a.trim_prefix("--seq=")
		elif a.begins_with("--every="): seq_every = int(a.trim_prefix("--every="))
		elif a.begins_with("--from="): seq_from = int(a.trim_prefix("--from="))
		elif a.begins_with("--p1="): model_ids[0] = a.trim_prefix("--p1=")
		elif a.begins_with("--p2="): model_ids[1] = a.trim_prefix("--p2=")
		elif a.begins_with("--p2hp="): p2_hp = int(a.trim_prefix("--p2hp="))
		elif a.begins_with("--seed="): demo_seed = int(a.trim_prefix("--seed="))
		elif a == "--demo": demo_on = true
		elif a.begins_with("--stills="): stills_dir = a.trim_prefix("--stills=")
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a1d3e")
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	env.adjustment_enabled = true
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":   # desktop (Forward+): glow on the brass and sparks, SMAA from project settings
		env.glow_enabled = true; env.glow_intensity = 0.5; env.glow_bloom = 0.04; env.glow_hdr_threshold = 1.0
	_build_stage()
	spark_mesh = _star_mesh()
	sfx = Sfx.Pool.new(); add_child(sfx)
	cam = Camera3D.new()
	cam.fov = 21.0
	add_child(cam)
	if cfg.get("mode", "") == "cpu":
		cpu = CpuBrain.new(int(cfg.get("tier", 4)), 1, demo_seed if demo_on else int(Time.get_ticks_usec()))
		if demo_on: cpu1 = CpuBrain.new(int(cfg.get("tier", 4)), 0, demo_seed + 100)
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

func _exit_tree() -> void:
	if online and link != null: link.close()

func _reset() -> void:
	match_sim = MatchSim.new(fighter_ids[0], fighter_ids[1], int(link.info.seed) if online else 1, 3)
	if online:
		session = RollbackSession.new(match_sim, link.local_index())
		link.bind_session(session)
	for v in views: v.queue_free()
	views.clear()
	var swaps := [0.0, 1.0 if model_ids[0] == model_ids[1] else 0.0]   # same model on both sides: P2 gets the hue swap
	for i in 2:
		var v := FighterView.new()
		add_child(v)
		v.setup(match_sim.world.fighters[i], model_ids[i], swaps[i])
		views.append(v)
	_script_t = 0
	if p2_hp > 0: match_sim.world.fighters[1].hp = p2_hp
	for sp in sparks: sp[0].queue_free()
	sparks.clear()
	shake = 0.0; nudge = 0.0; ko_k = 0.0
	if rematch: rematch.hide()
	if hud: hud.reset_state()
	_cam_follow(true)

func _build_stage() -> void:
	stage = ParallaxStage.new()
	add_child(stage)
	stage.setup(env, String(cfg.get("stage", "stage1")))

func _build_hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = HudTheme.build()
	layer.add_child(root)
	hud = FightHud.new(); hud.names = names; hud.need = match_sim.need; hud.round_seconds = SimConst.ROUND_SECONDS
	root.add_child(hud)
	banner_pivot = Node2D.new(); banner_pivot.position = Vector2(640, 190); banner_pivot.skew = -0.16
	root.add_child(banner_pivot)
	banner = _label(banner_pivot, Vector2(-640, -60), "HudBanner")
	banner.size = Vector2(1280, 120); banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.theme = root.theme    # a Node2D parent does not pass the theme down
	info = _label(root, Vector2(40, 64), "HudInfo")
	hint = _label(root, Vector2(40, 690), "HudHint")
	hint.text = "P1 %s | F1 help | F2 boxes | F3 debug | R restart" % Controls.describe("p1")
	if cfg.get("mode", "") == "training": hint.text = TRAINING_HINT % DUMMY[0]
	hint.visible = cfg.get("mode", "") == "training"; info.visible = false
	if cfg.get("mode", "") == "training":
		tools = TrainingTools.new()
		input_label = _label(root, Vector2(40, 330), "HudInfo"); input_label.visible = false
		adv_label = _label(root, Vector2(540, 250), "HudBanner"); adv_label.size = Vector2(200, 80)
		adv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; adv_label.add_theme_font_size_override("font_size", 64); adv_label.visible = false
	rematch = VBoxContainer.new()      # end-of-match menu: Rematch / Quit, keyboard and gamepad focus
	rematch.position = Vector2(440, 380); rematch.size = Vector2(400, 220)
	rematch.add_theme_constant_override("separation", 12)
	var items := [["REMATCH", _rematch], ["CHARACTER SELECT", func(): exit.emit("select")], ["MAIN MENU", func(): exit.emit("menu")]] if not cfg.is_empty() else [["REMATCH", _reset], ["QUIT", get_tree().quit]]
	if online: items = [["MAIN MENU", func(): exit.emit("menu")]]
	for item in items:
		if item[0] == "QUIT" and OS.has_feature("web"): continue
		var b := _menu_button(item[0]); b.pressed.connect(item[1]); rematch.add_child(b)
	rematch.hide()
	root.add_child(rematch)
	_build_pause(root)
	if TouchControls.wanted() and (online or cfg.get("mode", "versus") != "versus" or OS.get_cmdline_user_args().has("--touch")):
		touch = TouchControls.new(); root.add_child(touch)

func _menu_button(text: String) -> Button:
	var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): sfx.play("ui_confirm"))
	b.focus_entered.connect(func(): sfx.play("ui_move"))
	return b

func _rematch() -> void:
	_reset()
	if cpu: cpu.set_tier(cpu.tier)

func _build_pause(root: Control) -> void:
	pause_menu = VBoxContainer.new(); pause_menu.position = Vector2(440, 230); pause_menu.size = Vector2(400, 300)
	pause_menu.add_theme_constant_override("separation", 12)
	var title := Label.new(); title.text = "PAUSED"; title.theme_type_variation = "HudBanner"
	title.add_theme_font_size_override("font_size", 72); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_menu.add_child(title)
	var rows := [["RESUME", func(): _set_pause(false)], ["RESTART", func(): _set_pause(false); _rematch()]]
	if online: rows = [["RESUME", func(): _set_pause(false)]]           # the match cannot be paused: the menu is an overlay
	if cfg.get("mode", "") == "training":
		dummy_btn = _menu_button("DUMMY: " + DUMMY[dummy].to_upper()); dummy_btn.pressed.connect(_next_dummy)
		pause_menu.add_child(dummy_btn)
	for r in rows:
		var b := _menu_button(r[0]); b.pressed.connect(r[1]); pause_menu.add_child(b)
	if not cfg.is_empty():
		var q := _menu_button("QUIT TO MENU"); q.pressed.connect(func(): exit.emit("menu")); pause_menu.add_child(q)
	pause_menu.hide()
	root.add_child(pause_menu)

func _set_pause(on: bool) -> void:
	paused = on and not online; pause_menu.visible = on
	if on: pause_menu.get_child(1).grab_focus()

func _next_dummy() -> void:
	dummy = (dummy + 1) % DUMMY.size()
	if dummy_btn: dummy_btn.text = "DUMMY: " + DUMMY[dummy].to_upper()
	hint.text = TRAINING_HINT % DUMMY[dummy]

## P2 input: the human, the CPU brain, or the training dummy.
func _p2_input() -> Dictionary:
	match cfg.get("mode", "versus"):
		"cpu":
			if cpu and match_sim.inputs_live(): return cpu.think(match_sim.world.fighters)
			return WorldSim.neutral()
		"training": return _dummy_input()
	return _read("p2")

func _dummy_input() -> Dictionary:
	var i := WorldSim.neutral()
	var fs := match_sim.world.fighters
	var low: bool = fs[0].attacking() and not fs[0].cur.get("hits", []).is_empty() and fs[0].cur.hits[0].get("level", "mid") == "low"
	match DUMMY[dummy]:
		"crouch": i.down = true
		"block all": i.buttons = SimConst.BL; i.down = low
		"random block":
			_dummy_t -= 1
			if _dummy_t <= 0: _dummy_t = 20 + (match_sim.world.tick * 7919) % 50; _dummy_block = (match_sim.world.tick * 31) % 3 != 0
			if _dummy_block: i.buttons = SimConst.BL; i.down = low
	return i

## Training: no clock, no K.O. (the dummy is topped up when it gets low).
func _training_rules() -> void:
	match_sim.timer_ticks = SimConst.ROUND_SECONDS * SimConst.TICK_HZ
	for f in match_sim.world.fighters:
		if f.hp < int(f.stats.hp) * 0.25: f.hp = int(f.stats.hp)

func _training_readouts(p1_in: Dictionary) -> void:
	tools.record_input(p1_in)
	tools.update(match_sim.world.fighters, match_sim.world.tick)
	if input_label.visible: input_label.text = "INPUTS\n" + tools.input_lines()
	adv_label.visible = tools.adv_left > 0
	if adv_label.visible:
		adv_label.text = tools.adv_text
		adv_label.modulate = Color("7dff9a") if tools.adv_positive() else Color("ff6a5a")

func _label(parent: Node, pos: Vector2, variation: String) -> Label:
	var l := Label.new(); l.position = pos
	l.theme_type_variation = variation
	parent.add_child(l)
	return l

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") and not rematch.visible and seq_dir == "" and shot == "":
		_set_pause(not pause_menu.visible); get_viewport().set_input_as_handled(); return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F2: show_boxes = not show_boxes
		elif e.physical_keycode == KEY_F3: info.visible = not info.visible
		elif e.physical_keycode == KEY_F4 and input_label: input_label.visible = not input_label.visible
		elif e.physical_keycode == KEY_F1: help_on = not help_on; hint.visible = help_on
		elif e.physical_keycode == KEY_TAB and cfg.get("mode", "") == "training": _next_dummy()
		elif e.physical_keycode == KEY_R: _reset()

func _read(p: String) -> Dictionary:
	var i := WorldSim.neutral()
	i.left = Input.is_action_pressed(p + "_left"); i.right = Input.is_action_pressed(p + "_right")
	i.up = Input.is_action_pressed(p + "_up"); i.down = Input.is_action_pressed(p + "_down")
	for b in BUTTONS:
		if Input.is_action_pressed(p + "_" + b): i.buttons |= BUTTONS[b]
	return i

## Demo script (--script): P1 walks in and shows every button, the crouch normals and a jump attack; P2 mixes standing, crouching and blocking.
## The loop repeats until the round ends: distinct moves, lows, a knockdown and a KO into the win pose.
func _scripted() -> Array:
	var a := WorldSim.neutral(); var b := WorldSim.neutral()
	if not match_sim.inputs_live(): return [a, b]
	_script_t += 1
	var fs := match_sim.world.fighters
	var gap := absf(fs[1].x - fs[0].x)
	if gap > 58.0 and _script_t < 300:
		a.right = true
	else:
		var k := _script_t % 460
		if k >= 120 and k < 262: a.down = true                  # crouch for the 2L / 2M / 2H string
		if k == 262: a.up = true; a.right = true                 # jump forward
		match k:
			0, 330, 280: a.buttons = SimConst.L
			16, 150, 345: a.buttons = SimConst.M
			40, 175, 370: a.buttons = SimConst.H
			133: a.buttons = SimConst.L
			80: a.buttons = SimConst.S
			420: a.buttons = SimConst.THROW
	var k2 := _script_t % 240
	if k2 >= 90 and k2 < 130: b.down = true
	elif k2 >= 150 and k2 < 175: b.buttons = SimConst.BL
	elif k2 == 200: b.buttons = SimConst.L
	return [a, b]

func _tick(dt: float, inputs: Array) -> void:
	if p2_hp > 0 and match_sim.phase == "call": match_sim.world.fighters[1].hp = p2_hp   # demo: every round ends fast
	var before: String = match_sim.phase
	match_sim.step(inputs)
	_present(dt, before, match_sim.world.events)

## Online: one rollback session tick, then the same presentation. Events come de-duplicated from the session (resimulated ticks do not replay SFX).
func _online_tick(dt: float) -> void:
	link.poll(dt)
	if online_msg == "":
		if session.desync: online_msg = "OUT OF SYNC"
		elif session.is_disconnected() or link.transport.error != "": online_msg = "CONNECTION LOST"
	if online_msg != "":
		_present(dt, match_sim.phase, [])
		return
	var before: String = match_sim.phase
	session.advance(_read("p1"))
	link.poll(0.0)                 # send this tick's packets right away
	_present(dt, before, session.events)

func _present(dt: float, before: String, events: Array) -> void:
	if match_sim.phase != before: _announce()
	for e in events:
		var d: FighterSim = match_sim.world.fighters[e.def] if e.has("def") else null
		var dir := signf(d.x - match_sim.world.fighters[e.att].x) if d else 0.0
		match e.type:
			"hit":
				if tools: tools.on_contact(int(e.att), int(e.def))
				shake = maxf(shake, clampf(0.02 + float(e.dmg) * 0.0007, 0.02, 0.09) * 0.5)   # half amplitude; the killing blow gets the full "ko" kick
				if e.heavy: nudge = dir * 0.2
				_spark(d, dir, 0.55 if e.heavy else 0.36, Color("fff3c0") if e.heavy else Color("ffd35a"), e.get("level", "mid"), "hit_h" if e.heavy else "hit_l" if int(e.dmg) < 55 else "hit_m")
				sfx.play("hit_h" if e.heavy else "hit_l" if int(e.dmg) < 55 else "hit_m")
				if stills_dir != "" and (e.heavy or int(e.dmg) >= 60) and match_sim.world.tick - _still_tick > 150: _still_tick = match_sim.world.tick; _save_still()
			"throw":
				shake = maxf(shake, 0.07); nudge = dir * 0.25
				_spark(d, dir, 0.6, Color("fff3c0"), "mid", "hit_h"); sfx.play("hit_h", 0.85)
			"grab": sfx.play("block", 0.7)
			"tech": shake = maxf(shake, 0.03); sfx.play("block", 1.3)
			"block":
				if tools: tools.on_contact(int(e.att), int(e.def))
				shake = maxf(shake, 0.012)
				_spark(d, dir, 0.18, Color("9fd0ff"), "mid", "block"); sfx.play("block")
			"ko":
				shake = maxf(shake, 0.12); nudge = dir * 0.3
				sfx.play("ko")
	for f in match_sim.world.fighters:      # swish just before the active frames
		if f.attacking() and f.cur.has("startup") and f.st == int(f.cur.startup) and f.cur.get("kind", "") != "throw":
			sfx.play("whoosh", 1.35 if f.cur.weight <= 1 else 1.0 if f.cur.weight == 2 else 0.75)
	shake *= 0.84
	nudge *= 0.88
	for v in views: v.present(dt, match_sim.world.tick)
	_sparks(dt)
	_ko_look(dt)

func _save_still() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(stills_dir)
	get_viewport().get_texture().get_image().save_png("%s/hit%02d.png" % [stills_dir, _stills]); _stills += 1

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
	if paused: return
	if cfg.get("mode", "") == "training": _training_rules()
	if online:
		_online_tick(dt)
		_cam_follow(false); _hud(); _draw_boxes()
		return
	var p1_in: Dictionary = cpu1.think(match_sim.world.fighters) if cpu1 and match_sim.inputs_live() else _read("p1")
	_tick(dt, _scripted() if script_mode else [p1_in, _p2_input()])
	if tools: _training_readouts(p1_in)
	_cam_follow(false)
	_hud()
	_draw_boxes()

func _cam_follow(snap: bool) -> void:
	var fs := match_sim.world.fighters
	var mid := ((fs[0].x + fs[1].x) * 0.5 - CX) * W
	var sep := absf(fs[1].x - fs[0].x) * W
	var dist := clampf((sep + 1.8) / 0.66, 7.4, 12.0)   # fighters fill about 60 % of the frame height; zooms out only as they separate
	var zoomed := dist * (1.0 - 0.2 * ko_k)
	var target := Vector3(AirshipDeck.clamp_camera_x(mid + nudge, zoomed), 1.0, zoomed)
	cam.position = target if snap else cam.position.lerp(target, 0.12)
	if shake > 0.002:
		var t := float(match_sim.world.tick)
		cam.position += Vector3(sin(t * 12.9898), cos(t * 78.233), 0.0) * shake
	stage.update(cam)

func _hud() -> void:
	var fs := match_sim.world.fighters
	hud.update_state([clampf(float(fs[0].hp) / float(fs[0].stats.hp), 0.0, 1.0), clampf(float(fs[1].hp) / float(fs[1].stats.hp), 0.0, 1.0)],
		match_sim.seconds_left(), match_sim.wins, [fs[1].combo_hits, fs[0].combo_hits], get_process_delta_time())
	banner.text = _banner()
	var pop := 1.0
	if match_sim.phase in ["ko", "timeup", "call", "fight", "over"] and match_sim.pt < 4: pop = 1.0 + 1.1 * (1.0 - match_sim.pt / 4.0)   # 4-frame punch-in
	banner_pivot.scale = Vector2(pop, pop)
	var over: bool = match_sim.phase == "over" or online_msg != ""
	if online_msg != "": banner.text = online_msg
	if touch: touch.enabled = not paused and not over and not pause_menu.visible
	if over and not rematch.visible: rematch.get_child(0).grab_focus()
	rematch.visible = over
	info.text = "P1 %s | P2 %s | combo %d | %d fps | %s | %d draws" % [fs[0].anim(), fs[1].anim(), fs[1].combo_hits, Engine.get_frames_per_second(), RenderingServer.get_current_rendering_method(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]

## Announcer line on each phase change: ROUND n, FIGHT!, winner. The pack has no "K.O." call, so the K.O. gets the impact layers only.
func _announce() -> void:
	match match_sim.phase:
		"call": sfx.play("voice_final_round" if match_sim.final_round else "voice_round_%d" % clampi(match_sim.round_no, 1, 3))
		"fight": sfx.play("voice_fight")
		"ko": sfx.play("voice_ko")
		"timeup": sfx.play("voice_time")
		"over": sfx.play("voice_perfect" if match_sim.perfect else "voice_winner")

func _banner() -> String:
	match match_sim.phase:
		"call": return "ROUND %d" % match_sim.round_no
		"fight": return "FIGHT!"
		"ko": return "K.O."
		"timeup": return "TIME UP"
		"over": return "DRAW" if match_sim.match_winner < 0 else "%s WINS" % names[match_sim.match_winner]
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

## Impact burst at the defender: a flat star that pops and fades in about 0.15 s (additive, unshaded, facing the side camera).
## Effect by id (data/fx.json): the pack's sprite sheet when it is there, else the built-in star spark.
func _spark(d: FighterSim, dir: float, size: float, color: Color, level: String, id := "hit_m") -> void:
	if d == null: return
	if FxSheet.exists(id):
		var y0 := 0.35 if level == "low" else 1.15 + d.y * W
		add_child(FxSheet.make(id, Vector3((d.x - CX) * W - dir * 0.18, y0, 0.6), dir < 0.0))
		return
	var n := MeshInstance3D.new(); n.mesh = spark_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color; m.no_depth_test = true
	n.material_override = m
	var y := 0.35 if level == "low" else 1.15 + d.y * W
	n.position = Vector3((d.x - CX) * W - dir * 0.18, y, 0.6)
	n.rotation.z = randf() * TAU
	add_child(n)
	sparks.append([n, 0.0, 0.22, size])

func _sparks(dt: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var sp: Array = sparks[i]
		sp[1] += dt
		var k: float = clampf(sp[1] / sp[2], 0.0, 1.0)
		var node: MeshInstance3D = sp[0]
		node.scale = Vector3.ONE * float(sp[3]) * (0.4 + 1.1 * sqrt(k))
		(node.material_override as StandardMaterial3D).albedo_color.a = 1.0 - k * k
		if k >= 1.0:
			node.queue_free(); sparks.remove_at(i)

func _star_mesh() -> ArrayMesh:
	var verts := PackedVector3Array(); var cols := PackedColorArray()
	var spikes := 8
	for i in spikes:
		var a0 := TAU * i / spikes; var a1 := TAU * (i + 0.5) / spikes; var a2 := TAU * (i + 1) / spikes
		var r := 1.0 if i % 2 == 0 else 0.62
		verts.append_array([Vector3.ZERO, Vector3(cos(a0), sin(a0), 0) * 0.28, Vector3(cos(a1), sin(a1), 0) * r])
		verts.append_array([Vector3.ZERO, Vector3(cos(a1), sin(a1), 0) * r, Vector3(cos(a2), sin(a2), 0) * 0.28])
		cols.append_array([Color.WHITE, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0), Color.WHITE, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5)])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

## KO slow-mo look: desaturate and darken while the final hit plays out, then ease back for the next round.
func _ko_look(dt: float) -> void:
	var slow: bool = match_sim.phase == "ko" and match_sim.pt > int(match_sim.pace[0])
	ko_k = move_toward(ko_k, 1.0 if slow else 0.0, dt * (4.0 if slow else 2.0))
	env.adjustment_saturation = lerpf(1.0, 0.3, ko_k)
	env.adjustment_brightness = lerpf(1.0, 0.82, ko_k)
	env.adjustment_contrast = lerpf(1.0, 1.15, ko_k)
