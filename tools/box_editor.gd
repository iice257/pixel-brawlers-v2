extends Node3D
## Debug box editor: shows a fighter in the side-view pose for any move and tick, with its hit boxes drawn over it, edits the first
## hit window and boxes, and saves to data/fighters/<id>.json. Run: godot --path . res://tools/box_editor.tscn (editor builds only).
## Keys: Q/E move, A/D tick, Tab select hit entry, arrows move box (Shift = 4 px), Ctrl+arrows resize,
##       [ ] hit starts earlier/later, - = hit ends earlier/later, J K recovery -/+, S save, F5 reload from disk.
## Hurt and push boxes are per stance (data "boxes" per fighter, else SimConst.BOXES), so they are shown here but not edited. Pick a fighter with --fighter=<id>.
const W := FighterView.WORLD_PER_PX
const CX := FighterView.CENTER_X
var FIGHTER := "placeholder"

var data: Dictionary
var move_ids: Array = []
var mi := 0
var tick := 1
var sel := 0
var sim: FighterSim
var view: FighterView
var cam: Camera3D
var label: Label
var box_mesh: MeshInstance3D
var dirty := false

func _ready() -> void:
	var win := get_window()
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("2a1d3e")
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(16, 6); floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("3a2a52"); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm; add_child(floor_mesh)
	cam = Camera3D.new(); cam.fov = 21.0; cam.position = Vector3(0, 1.05, 7.5); add_child(cam)
	var layer := CanvasLayer.new(); add_child(layer)
	label = Label.new(); label.position = Vector2(24, 16)
	label.add_theme_font_size_override("font_size", 16)
	layer.add_child(label)
	box_mesh = MeshInstance3D.new(); box_mesh.mesh = ImmediateMesh.new()
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true; bm.no_depth_test = true
	box_mesh.material_override = bm; add_child(box_mesh)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fighter="): FIGHTER = a.trim_prefix("--fighter=")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--move="): mi = maxi(FighterSim.load_data(FIGHTER).moves.keys().find(a.trim_prefix("--move=")), 0)
		elif a.begins_with("--tick="): tick = int(a.trim_prefix("--tick="))
	_load()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(a.trim_prefix("--shot="))
			get_tree().quit()

func _load() -> void:
	data = FighterSim.load_data(FIGHTER)
	move_ids = data.moves.keys()
	mi = clampi(mi, 0, move_ids.size() - 1)
	dirty = false
	_apply()

func _move() -> Dictionary:
	return data.moves[move_ids[mi]]

func _total() -> int:
	var m := _move()
	return int(m.startup) + int(m.active) + int(m.recovery)

func _hits() -> Array:
	return _move().get("hits", [])

## Puts a fresh sim fighter into the chosen move at the chosen tick and poses the model from it.
func _apply() -> void:
	var m := _move()
	sim = FighterSim.new(FIGHTER, 0, CX, 1)
	sim.moves = data.moves
	sim.cur = m
	sim.state = "airatk" if m.kind == "air" else "attack"
	sim.y = 40.0 if m.kind == "air" else 0.0
	tick = clampi(tick, 1, _total())
	sim.st = tick
	if view: view.queue_free()
	view = FighterView.new(); add_child(view)
	view.setup(sim, String(data.get("model", "a0")), 0.0)
	view.present(1.0 / 60.0, tick)
	sel = clampi(sel, 0, maxi(_hits().size() - 1, 0))
	_refresh()

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed): return
	var k: Key = e.physical_keycode
	var step := 4 if e.shift_pressed else 1
	var m := _move()
	var h: Dictionary = _hits()[sel] if not _hits().is_empty() else {}
	match k:
		KEY_Q: mi = (mi - 1 + move_ids.size()) % move_ids.size(); tick = 1; _apply(); return
		KEY_E: mi = (mi + 1) % move_ids.size(); tick = 1; _apply(); return
		KEY_A: tick -= 1; _apply(); return
		KEY_D: tick += 1; _apply(); return
		KEY_TAB: sel = (sel + 1) % maxi(_hits().size(), 1); _refresh(); return
		KEY_S: _save(); return
		KEY_F5: _load(); return
		KEY_J: m.recovery = maxi(int(m.recovery) - 1, 1); dirty = true
		KEY_K: m.recovery = int(m.recovery) + 1; dirty = true
		KEY_BRACKETLEFT: if not h.is_empty(): h["from"] = maxi(int(h["from"]) - 1, 1); dirty = true
		KEY_BRACKETRIGHT: if not h.is_empty(): h["from"] = mini(int(h["from"]) + 1, int(h["to"])); dirty = true
		KEY_MINUS: if not h.is_empty(): h["to"] = maxi(int(h["to"]) - 1, int(h["from"])); dirty = true
		KEY_EQUAL: if not h.is_empty(): h["to"] = int(h["to"]) + 1; dirty = true
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if h.is_empty(): return
			var b: Array = h.box
			var dx := (-step if k == KEY_LEFT else step if k == KEY_RIGHT else 0)
			var dy := (step if k == KEY_UP else -step if k == KEY_DOWN else 0)
			if e.ctrl_pressed:
				b[2] = maxf(float(b[2]) + dx, 2.0); b[3] = maxf(float(b[3]) + dy, 2.0)
			else:
				b[0] = float(b[0]) + dx; b[1] = float(b[1]) + dy
			dirty = true
		_: return
	FrameData.sync(m)
	_apply()

func _save() -> void:
	var path := ProjectSettings.globalize_path("res://data/fighters/%s.json" % FIGHTER)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " "))
	f.close()
	dirty = false
	_refresh()

func _refresh() -> void:
	var m := _move()
	var fd := FrameData.derive(m)
	var h: Dictionary = _hits()[sel] if not _hits().is_empty() else {}
	var t := "%s  [%s]  tick %d / %d%s\n" % [FIGHTER, move_ids[mi], tick, _total(), "   *UNSAVED*" if dirty else ""]
	t += "startup %d  active %d  recovery %d   adv hit %+d  block %+d\n" % [fd.startup, fd.active, fd.recovery, fd.adv_hit, fd.adv_block]
	if not h.is_empty():
		t += "hit %d/%d  window %d-%d  box %s  dmg %d  %s\n" % [sel + 1, _hits().size(), h["from"], h["to"], str(h.box), h.dmg, h.level]
	t += "Q/E move  A/D tick  Tab hit  arrows box (Shift x4)  Ctrl+arrows size  [ ] from  - = to  J K recovery  S save  F5 reload"
	label.text = t
	_draw()

func _draw() -> void:
	var im: ImmediateMesh = box_mesh.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for r in sim.hurt_boxes(): _rect(im, r, Color("41e07a"))
	_rect(im, sim.push_box(), Color("4da3ff"))
	for i in _hits().size():
		var live: bool = tick >= int(_hits()[i]["from"]) and tick <= int(_hits()[i]["to"])
		_rect(im, sim.hit_rect(_hits()[i]), Color("ffe14d") if i == sel else Color("ff4a4a") if live else Color("a04040"))
	im.surface_end()

func _rect(im: ImmediateMesh, r: Rect2, c: Color) -> void:
	var x0 := (r.position.x - CX) * W; var x1 := (r.end.x - CX) * W
	var y0 := r.position.y * W; var y1 := r.end.y * W
	var pts := [Vector3(x0, y0, 0.4), Vector3(x1, y0, 0.4), Vector3(x1, y1, 0.4), Vector3(x0, y1, 0.4)]
	for i in 4:
		im.surface_set_color(c); im.surface_add_vertex(pts[i])
		im.surface_set_color(c); im.surface_add_vertex(pts[(i + 1) % 4])
