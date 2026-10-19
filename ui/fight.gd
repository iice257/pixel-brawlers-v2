extends Node2D
## G0 fight scene: steps WorldSim at 60 Hz from the P1/P2 input actions and renders it.
## Fighters are placeholder rectangles tinted by their anim_map entry until a sprite pack is mapped (G3).
## F2 toggles the box overlay, R resets. User arg --shot=<file.png> plays a scripted walk + jump, saves the frame and quits (QA).

const BUTTONS := { "lp": SimConst.LP, "hp": SimConst.HP, "lk": SimConst.LK, "hk": SimConst.HK, "block": SimConst.BL, "throw": SimConst.THROW }
const BOX_COLORS := { "push": Color("4da3ff"), "hurt": Color("41e07a") }

var world: WorldSim
var maps: Array[AnimMap] = []
var cam_x := 0.0
var show_boxes := true
var hint: Label
var info: Label
var shot_path := ""
var script_tick := -1

func _ready() -> void:
	_reset()
	var layer := CanvasLayer.new(); add_child(layer)
	hint = _label(layer, Vector2(4, 192), Color("8a80b0"))
	hint.text = "P1 %s\nF2 boxes  R reset" % Controls.describe("p1")
	info = _label(layer, Vector2(4, 4), Color("ffcf33"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.trim_prefix("--shot="); script_tick = 0

func _label(parent: Node, pos: Vector2, color: Color) -> Label:
	var l := Label.new(); l.position = pos
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l); return l

func _reset() -> void:
	world = WorldSim.new("placeholder", "placeholder", 1)
	maps = [AnimMap.load_for(world.fighters[0].id), AnimMap.load_for(world.fighters[1].id)]
	cam_x = _cam_target()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F2: show_boxes = not show_boxes
		elif e.physical_keycode == KEY_R: _reset()

func _read(p: String) -> Dictionary:
	var i := WorldSim.neutral()
	i.left = Input.is_action_pressed(p + "_left"); i.right = Input.is_action_pressed(p + "_right")
	i.up = Input.is_action_pressed(p + "_up"); i.down = Input.is_action_pressed(p + "_down")
	for b in BUTTONS: if Input.is_action_pressed(p + "_" + b): i.buttons |= BUTTONS[b]
	return i

# QA script: P1 walks in for 30 ticks, then jumps forward; frozen mid-air at tick 46.
func _scripted() -> Array:
	var a := WorldSim.neutral()
	if script_tick < 30: a.right = true
	elif script_tick < 33: a.right = true; a.up = true
	return [a, WorldSim.neutral()]

func _physics_process(_dt: float) -> void:
	if script_tick >= 0:
		if script_tick < 46: world.step(_scripted()); script_tick += 1
		elif script_tick == 46: script_tick += 1; _save_shot.call_deferred()
	else:
		world.step([_read("p1"), _read("p2")])
	cam_x = lerpf(cam_x, _cam_target(), 0.2)
	var f0 := world.fighters[0]; var f1 := world.fighters[1]
	info.text = "TICK %d  P1 %s x%d y%d  P2 %s x%d" % [world.tick, f0.state, f0.x, f0.y, f1.state, f1.x]
	queue_redraw()

func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	get_tree().quit()

func _cam_target() -> float:
	var mid := (world.fighters[0].x + world.fighters[1].x) / 2.0
	return clampf(mid - 192.0, 0.0, SimConst.STAGE_W - 384.0)

# world (x, y up) -> screen
func _sx(x: float) -> float: return roundf(x - roundf(cam_x))
func _sy(y: float) -> float: return roundf(SimConst.FLOOR_Y - y)
func _srect(r: Rect2) -> Rect2: return Rect2(_sx(r.position.x), _sy(r.end.y), r.size.x, r.size.y)

func _draw() -> void:
	# placeholder stage: sky bands, floor, a marker every 64 px so camera motion reads
	draw_rect(Rect2(0, 0, 384, SimConst.FLOOR_Y), Color("1a1030"))
	draw_rect(Rect2(0, 120, 384, SimConst.FLOOR_Y - 120), Color("241640"))
	draw_rect(Rect2(0, SimConst.FLOOR_Y, 384, 216 - SimConst.FLOOR_Y), Color("2c1844"))
	for gx in range(0, SimConst.STAGE_W + 1, 64):
		draw_rect(Rect2(_sx(gx), SimConst.FLOOR_Y, 1, 6), Color("4a3070"))
	for f in world.fighters:
		var e := maps[f.idx].entry(f.anim())
		var body := _srect(f.push_box())
		draw_rect(body, e.get("color", Color.WHITE))
		draw_rect(body, Color("0a0614"), false, 1.0)
		var eye_x := body.position.x + (body.size.x - 6.0 if f.facing > 0 else 2.0)   # facing marker
		draw_rect(Rect2(eye_x, body.position.y + 6, 4, 4), Color("0a0614"))
		draw_rect(Rect2(_sx(f.x) - 10, SimConst.FLOOR_Y, 20, 2), Color(0, 0, 0, 0.35))   # floor shadow
	if show_boxes:
		for f in world.fighters:
			for h in f.hurt_boxes(): draw_rect(_srect(h), BOX_COLORS.hurt, false, 1.0)
			draw_rect(_srect(f.push_box()), BOX_COLORS.push, false, 1.0)
			draw_rect(Rect2(_sx(f.x), _sy(f.y) - 1, 1, 3), Color.WHITE)
