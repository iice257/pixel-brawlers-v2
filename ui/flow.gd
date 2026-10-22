class_name Flow
extends Control
## REDLINE front end: title -> main menu -> character select -> stage pick -> VS splash -> fight -> results (the fight scene owns the results menu).
## Everything works with keyboard or gamepad alone: menus use the ui_* actions (arrows/WASD/Enter/Esc and d-pad/A/B), character select uses the
## p1_* / p2_* actions. Transitions are a 0.36 s red wipe. Art slots: assets/ui/logo.png (title), assets/ui/portraits/<id>.png (character cards).

const FONT := preload("res://assets/fonts/Bangers-Regular.ttf")
const ROSTER := [
	{"id": "kestrel", "name": "KESTREL", "model": "a0", "tag": "Gadgeteer", "color": Color("3fe0d0")},
	{"id": "briggs", "name": "BRIGGS", "model": "a0", "tag": "Brawler", "color": Color("ffb23a")},
]
const TIER_NAMES := {1: "EASY", 2: "EASY", 3: "NORMAL", 4: "NORMAL", 5: "HARD", 6: "HARD", 7: "MAX", 8: "MAX"}
const SETTINGS := "user://settings.cfg"
const RED := Color("e3262f")
const INK := Color("0a0614")
const STEAM := Color("efe6d2")
const BRASS := Color("c9a14a")

var sfx: Sfx.Pool
var screen: Control
var mode := "versus"
var tier := 4
var picks := [0, 1]
var stage_id := "stage1"
var fight: Node
var _wipe: ColorRect
var _wipe_mat: ShaderMaterial
var _busy := false
var _ui: CanvasLayer
var _bg: Control

func _ready() -> void:
	var win := get_window()
	win.content_scale_size = Vector2i(1280, 720)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_extra_ui_keys()
	_load_settings()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = HudTheme.build()
	sfx = Sfx.Pool.new(); add_child(sfx)
	_ui = CanvasLayer.new(); _ui.layer = 5; add_child(_ui)
	_bg = BgDraw.new(); _bg.set_anchors_preset(Control.PRESET_FULL_RECT); _bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_bg)
	var wl := CanvasLayer.new(); wl.layer = 100; add_child(wl)
	_wipe = ColorRect.new(); _wipe.set_anchors_preset(Control.PRESET_FULL_RECT); _wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe_mat = ShaderMaterial.new(); _wipe_mat.shader = _wipe_shader(); _wipe_mat.set_shader_parameter("p", 0.0)
	_wipe.material = _wipe_mat
	wl.add_child(_wipe)
	var start := "title"
	var shot := ""
	var wait := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="): start = a.trim_prefix("--screen=")
		elif a.begins_with("--mode="): mode = a.trim_prefix("--mode=")
		elif a.begins_with("--tier="): tier = int(a.trim_prefix("--tier="))
		elif a.begins_with("--flowshot="): shot = a.trim_prefix("--flowshot=")
		elif a.begins_with("--wait="): wait = float(a.trim_prefix("--wait="))
	if start == "fight": _start_fight()
	else: _show(start)
	if shot != "": _capture(shot, wait)

## Capture hook for QA: save the viewport after `wait` seconds and quit.
func _capture(path: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

## Arrow/WASD/Enter plus the P1 keys drive the ui_* actions, so menus also work from the left hand on the fight keys.
func _extra_ui_keys() -> void:
	for pair in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A], ["ui_right", KEY_D], ["ui_accept", KEY_U]]:
		var e := InputEventKey.new(); e.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], e): InputMap.action_add_event(pair[0], e)

func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS) != OK: return
	AudioServer.set_bus_volume_db(0, linear_to_db(float(c.get_value("audio", "master", 1.0))))
	if bool(c.get_value("video", "fullscreen", false)) and not OS.has_feature("web"): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "master", db_to_linear(AudioServer.get_bus_volume_db(0)))
	c.set_value("video", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	c.save(SETTINGS)

# ------------------------------------------------------------------ transitions

func _wipe_shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type canvas_item;
uniform float p = 0.0;
void fragment() {
	float e = (UV.x + UV.y * 0.3) / 1.3;
	float a = p <= 1.0 ? step(e, p) : step(p - 1.0, e);
	vec3 col = mix(vec3(0.89, 0.15, 0.18), vec3(0.04, 0.02, 0.08), smoothstep(0.0, 0.06, abs(e - fract(p)) ));
	COLOR = vec4(vec3(0.89, 0.15, 0.18), a * step(0.0001, p) * step(p, 1.9999));
}"""
	return s

## Red wipe over the screen, swap what is shown at full cover, wipe off. Total 0.36 s.
func _go(change: Callable) -> void:
	if _busy: return
	_busy = true
	var tw := create_tween()
	tw.tween_method(func(v: float): _wipe_mat.set_shader_parameter("p", v), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(change)
	tw.tween_method(func(v: float): _wipe_mat.set_shader_parameter("p", v), 1.0, 2.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _busy = false)

func _show(name: String) -> void:
	if screen: screen.queue_free(); screen = null
	_bg.visible = true; _ui.visible = true
	match name:
		"title": screen = _title()
		"menu": screen = _menu()
		"controls": screen = _controls()
		"options": screen = _options()
		"select": screen = _select()
		"stage": screen = _stage()
		"vs": screen = _vs()
	if screen: _ui.add_child(screen)

func _goto(name: String) -> void:
	_go(func(): _show(name))

# ------------------------------------------------------------------ widgets

func _label(text: String, size: int, color := STEAM, outline := 8) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_override("font", FONT); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK); l.add_theme_constant_override("outline_size", outline)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(420, 52)
	b.add_theme_font_override("font", FONT); b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", STEAM); b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_hover_color", INK); b.add_theme_color_override("font_pressed_color", INK)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(INK, 0.55) if st == "normal" else STEAM
		sb.border_width_left = 8; sb.border_color = RED if st != "normal" else BRASS.darkened(0.4)
		sb.content_margin_left = 24; sb.content_margin_top = 2; sb.content_margin_bottom = 2
		sb.skew = Vector2(-0.12, 0)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func(): sfx.play("ui_confirm"))
	b.pressed.connect(cb)
	b.focus_entered.connect(func(): sfx.play("ui_move"))
	b.mouse_entered.connect(b.grab_focus)
	return b

func _column(x: float, y: float) -> VBoxContainer:
	var v := VBoxContainer.new(); v.position = Vector2(x, y)
	v.add_theme_constant_override("separation", 8)
	return v

func _root() -> Control:
	var c := Control.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c

func _wordmark(parent: Control, pos: Vector2, size: int) -> void:
	if ResourceLoader.exists("res://assets/ui/logo.png"):
		var t := TextureRect.new(); t.texture = load("res://assets/ui/logo.png")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.position = pos; t.size = Vector2(size * 4.2, size * 1.2)
		parent.add_child(t); return
	var shadow := _label("REDLINE", size, RED, 0); shadow.position = pos + Vector2(size * 0.04, size * 0.05)
	var main := _label("REDLINE", size, STEAM, int(size * 0.09)); main.position = pos
	for l in [shadow, main]:
		l.pivot_offset = Vector2(0, size * 0.6); l.rotation = -0.04
		parent.add_child(l)

# ------------------------------------------------------------------ title

func _title() -> Control:
	var r := _root()
	_wordmark(r, Vector2(150, 190), 200)
	var tag := _label("STEAM-POWERED FIGHTING", 34, BRASS); tag.position = Vector2(160, 400)
	r.add_child(tag)
	var press := _label("PRESS ANY KEY", 44, STEAM); press.position = Vector2(160, 540)
	r.add_child(press)
	var tw := press.create_tween().set_loops()
	tw.tween_property(press, "modulate:a", 0.25, 0.7); tw.tween_property(press, "modulate:a", 1.0, 0.7)
	var arm := Timer.new(); arm.wait_time = 0.35; arm.one_shot = true; arm.autostart = true; r.add_child(arm)
	r.set_meta("armed", false)
	arm.timeout.connect(func(): r.set_meta("armed", true))
	r.set_script(AnyKey)
	r.on_press = func(): sfx.play("ui_confirm"); _goto("menu")
	return r

# ------------------------------------------------------------------ main menu

func _menu() -> Control:
	var r := _root()
	_wordmark(r, Vector2(90, 60), 96)
	var col := _column(100, 190)
	var items := [
		["VERSUS", func(): mode = "versus"; _goto("select")],
		["VS CPU", func(): mode = "cpu"; _goto("select")],
		["TRAINING", func(): mode = "training"; _goto("select")],
		["CONTROLS", func(): _goto("controls")],
		["OPTIONS", func(): _goto("options")],
	]
	if not OS.has_feature("web"): items.append(["QUIT", func(): get_tree().quit()])
	var first: Button
	for it in items:
		var b := _button(it[0], it[1]); col.add_child(b)
		if first == null: first = b
		if it[0] == "VS CPU":
			var cb := _button("", func(): pass)
			cb.text = _tier_text(); col.add_child(cb)
			cb.pressed.connect(func(): tier = tier % 8 + 1; cb.text = _tier_text())
			cb.gui_input.connect(func(e: InputEvent):
				var d := 0
				if e.is_action_pressed("ui_left"): d = -1
				elif e.is_action_pressed("ui_right"): d = 1
				if d != 0:
					tier = clampi(tier + d, 1, 8); cb.text = _tier_text(); sfx.play("ui_move"); cb.accept_event())
	r.add_child(col)
	first.call_deferred("grab_focus")
	var hint := _label("ARROWS / WASD / D-PAD MOVE    ENTER / A SELECT    ESC / B BACK", 22, BRASS, 4); hint.position = Vector2(100, 660)
	r.add_child(hint)
	return r

func _tier_text() -> String:
	return "   CPU LEVEL  <  %d  %s  >" % [tier, TIER_NAMES[tier]]

# ------------------------------------------------------------------ controls / options

func _controls() -> Control:
	var r := _root()
	var t := _label("CONTROLS", 90, STEAM); t.position = Vector2(100, 60); r.add_child(t)
	var y := 190.0
	for p in ["p1", "p2"]:
		var h := _label("PLAYER %s" % p.trim_prefix("p"), 40, RED if p == "p1" else BRASS); h.position = Vector2(100, y); r.add_child(h)
		var d := _label(Controls.describe(p).replace(" | ", "     "), 26, STEAM, 4); d.position = Vector2(100, y + 52); d.size = Vector2(1080, 80)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(d); y += 150.0
	var g := _label("GAMEPAD  X LIGHT   Y MEDIUM   A HEAVY   B SPECIAL   BUMPERS BLOCK   RIGHT TRIGGER THROW", 24, BRASS, 4); g.position = Vector2(100, 490); r.add_child(g)
	var back := _button("BACK", func(): _goto("menu")); back.position = Vector2(100, 570); r.add_child(back)
	back.call_deferred("grab_focus")
	return r

func _options() -> Control:
	var r := _root()
	var t := _label("OPTIONS", 90, STEAM); t.position = Vector2(100, 60); r.add_child(t)
	var col := _column(100, 200)
	r.add_child(col)
	var vol := _label("VOLUME", 34, STEAM, 5); col.add_child(vol)
	var s := HSlider.new(); s.min_value = 0.0; s.max_value = 1.0; s.step = 0.05; s.custom_minimum_size = Vector2(460, 40)
	s.value = db_to_linear(AudioServer.get_bus_volume_db(0)); s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v: float): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))); _save_settings())
	s.focus_entered.connect(func(): sfx.play("ui_move"))
	col.add_child(s)
	if not OS.has_feature("web"):
		var fs := _button("FULLSCREEN: " + ("ON" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "OFF"), func(): pass)
		fs.pressed.connect(func():
			var on := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
			fs.text = "FULLSCREEN: " + ("ON" if on else "OFF"); _save_settings())
		col.add_child(fs)
	var back := _button("BACK", func(): _goto("menu")); col.add_child(back)
	s.call_deferred("grab_focus")
	return r

# ------------------------------------------------------------------ character select

func _select() -> Control:
	var sel := Select.new()
	sel.flow = self
	return sel

func _stage() -> Control:
	var r := _root()
	var t := _label("STAGE", 90, STEAM); t.position = Vector2(100, 60); r.add_child(t)
	var col := _column(100, 220); r.add_child(col)
	var first: Button
	for f in DirAccess.get_files_at("res://data/stages"):
		if not f.ends_with(".json"): continue
		var cfg: Dictionary = ParallaxStage.config(f.get_basename())
		var b := _button(String(cfg.name).to_upper(), func(): stage_id = f.get_basename(); _goto("vs"))
		col.add_child(b)
		if first == null: first = b
	var back := _button("BACK", func(): _goto("select")); col.add_child(back)
	if first: first.call_deferred("grab_focus")
	return r

# ------------------------------------------------------------------ VS splash, fight

func _vs() -> Control:
	var r := _root()
	var n0: String = ROSTER[picks[0]].name; var n1: String = ROSTER[picks[1]].name
	var a := _label(n0, 150, ROSTER[picks[0]].color); var b := _label(n1, 150, ROSTER[picks[1]].color)
	a.position = Vector2(-700, 150); b.position = Vector2(1400, 360)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; b.size = Vector2(700, 160)
	var vs := _label("VS", 220, RED, 20); vs.position = Vector2(540, 250); vs.scale = Vector2(3, 3); vs.modulate.a = 0.0; vs.pivot_offset = Vector2(100, 110)
	for n in [a, b, vs]: r.add_child(n)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(a, "position:x", 90.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "position:x", 490.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs, "scale", Vector2.ONE, 0.25).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs, "modulate:a", 1.0, 0.1).set_delay(0.3)
	var timer := Timer.new(); timer.wait_time = 1.7; timer.one_shot = true; timer.autostart = true; r.add_child(timer)
	timer.timeout.connect(_start_fight)
	r.set_script(AnyKey)
	r.on_press = func(): if r.get_meta("age", 0.0) > 0.6: _start_fight()
	return r

func _start_fight() -> void:
	if _busy or fight != null: return
	_go(func():
		if screen: screen.queue_free(); screen = null
		_bg.visible = false; _ui.visible = false
		var f: Node = load("res://a0/a0_fight.tscn").instantiate()
		f.cfg = {"mode": mode, "tier": tier, "stage": stage_id,
			"names": [ROSTER[picks[0]].name, ROSTER[picks[1]].name], "models": [ROSTER[picks[0]].model, ROSTER[picks[1]].model]}
		f.exit.connect(_on_fight_exit)
		fight = f; add_child(f))

func _on_fight_exit(action: String) -> void:
	_go(func():
		if fight: fight.queue_free(); fight = null
		_show("select" if action == "select" else "menu"))

# ------------------------------------------------------------------ helpers (inner classes)

## Any key, click or pad button after a short arm delay calls on_press once.
class AnyKey extends Control:
	var on_press: Callable
	func _process(dt: float) -> void: set_meta("age", float(get_meta("age", 0.0)) + dt)
	func _input(e: InputEvent) -> void:
		var hit: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventJoypadButton and e.pressed) or (e is InputEventMouseButton and e.pressed)
		if hit and float(get_meta("age", 0.0)) > 0.35 and on_press.is_valid():
			get_viewport().set_input_as_handled(); var cb := on_press; on_press = Callable(); cb.call()

## Animated backdrop: deep indigo with a red glow from the floor, drifting steam and a few slanted speed stripes.
class BgDraw extends Control:
	var t := 0.0
	func _process(dt: float) -> void: t += dt; queue_redraw()
	func _draw() -> void:
		var sz := size
		var top := Color("160f2a"); var bot := Color("4a1426")
		var steps := 24
		for i in steps:
			draw_rect(Rect2(0, sz.y * i / steps, sz.x, sz.y / steps + 1), top.lerp(bot, pow(float(i) / (steps - 1), 1.6)))
		for k in 7:
			var x := fposmod(k * 260.0 - t * (18.0 + k * 4.0), sz.x + 400.0) - 200.0
			draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 70, 0), Vector2(x - 130, sz.y), Vector2(x - 200, sz.y)]), PackedColorArray([Color(0.89, 0.15, 0.18, 0.06)]))
		for k in 5:
			var y := sz.y * (0.55 + 0.09 * k)
			var x := fposmod(t * (12.0 + 5 * k) + k * 370.0, sz.x + 500.0) - 250.0
			draw_circle(Vector2(x, y), 190.0 + 20.0 * k, Color(0.94, 0.72, 0.54, 0.035))
		draw_rect(Rect2(0, sz.y - 6, sz.x, 6), Color("e3262f"))

## Character select: P1 and P2 cursors over portrait cards (placeholder silhouettes until assets/ui/portraits/<id>.png exist).
class Select extends Control:
	var flow: Flow
	var idx := [0, 1]
	var locked := [false, false]
	var cpu_side := false
	var _age := 0.0
	var cards: Array = []

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		cpu_side = flow.mode != "versus"
		var t := flow._label("SELECT FIGHTER" if not cpu_side else "SELECT YOUR FIGHTER", 80, Flow.STEAM); t.position = Vector2(100, 40); add_child(t)
		for i in Flow.ROSTER.size():
			var c := Card.new(); c.data = Flow.ROSTER[i]; c.position = Vector2(290 + i * 360, 190); c.size = Vector2(320, 400); add_child(c); cards.append(c)
		var hint := flow._label("MOVE  LEFT / RIGHT     CONFIRM  LIGHT / ENTER / A     BACK  BLOCK / ESC / B", 22, Flow.BRASS, 4); hint.position = Vector2(100, 660); add_child(hint)

	func _process(dt: float) -> void:
		_age += dt
		for c in cards: c.tags = []
		for p in 2:
			var tag: String = "P%d" % (p + 1) if not (p == 1 and cpu_side) else ("CPU" if locked[1] or true else "")
			cards[idx[p]].tags.append([tag, p, locked[p]])
		for c in cards: c.queue_redraw()
		if _age < 0.3: return
		for p in 2:
			if p == 1 and cpu_side: continue
			if locked[p]:
				if _pressed(p, "block", "ui_cancel"): locked[p] = false; flow.sfx.play("ui_back")
				continue
			var pre := "p%d_" % (p + 1)
			var d := int(_pressed(p, "right", "ui_right")) - int(_pressed(p, "left", "ui_left"))
			if d != 0: idx[p] = posmod(idx[p] + d, Flow.ROSTER.size()); flow.sfx.play("ui_move")
			if _pressed(p, "light", "ui_accept"): locked[p] = true; flow.sfx.play("ui_confirm")
			elif _pressed(p, "block", "ui_cancel") and not locked[0] and not locked[1]: flow.sfx.play("ui_back"); flow._goto("menu"); set_process(false); return
		if cpu_side and locked[0] and not locked[1]:
			idx[1] = (idx[0] + 1) % Flow.ROSTER.size(); locked[1] = true
		if locked[0] and locked[1]:
			flow.picks = [idx[0], idx[1]]; set_process(false); flow._goto("stage")

	## P1 also answers the ui_* actions when there is no human P2 to clash with the arrow keys.
	func _pressed(p: int, act: String, ui: String) -> bool:
		if Input.is_action_just_pressed("p%d_%s" % [p + 1, act]): return true
		return p == 0 and cpu_side and Input.is_action_just_pressed(ui)

class Card extends Control:
	var data := {}
	var tags: Array = []
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Flow.INK); draw_rect(r.grow(-6), Color("1e1530"))
		var col: Color = data.color
		var path := "res://assets/ui/portraits/%s.png" % data.id
		if ResourceLoader.exists(path):
			draw_texture_rect(load(path), r.grow(-6), false)
		else:                                                         # placeholder silhouette: head and shoulders in the fighter's colour
			var c := Vector2(size.x * 0.5, size.y * 0.52)
			draw_polygon(PackedVector2Array([c + Vector2(-110, 150), c + Vector2(-90, 40), c + Vector2(-40, 20), c + Vector2(40, 20), c + Vector2(90, 40), c + Vector2(110, 150)]), PackedColorArray([col.darkened(0.55)]))
			draw_circle(c + Vector2(0, -50), 62.0, col.darkened(0.45))
			draw_arc(c + Vector2(0, -50), 62.0, 0, TAU, 32, col, 4.0)
		draw_rect(Rect2(6, size.y - 96, size.x - 12, 90), Color(Flow.INK, 0.85))
		draw_string(Flow.FONT, Vector2(20, size.y - 42), data.name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 54, Flow.STEAM)
		draw_string(Flow.FONT, Vector2(22, size.y - 16), String(data.tag).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 24, Flow.BRASS)
		draw_rect(r, Flow.BRASS, false, 4.0)
		var y := 14.0
		for t in tags:
			var c: Color = Color("3fe0d0") if int(t[1]) == 0 else Color("ffb23a")
			draw_rect(r.grow(-2), c, false, 6.0 if t[2] else 3.0)
			draw_rect(Rect2(14 + int(t[1]) * 70.0, y, 62, 34), c)
			draw_string(Flow.FONT, Vector2(20 + int(t[1]) * 70.0, y + 28), ("%s" % t[0]) + ("!" if t[2] else ""), HORIZONTAL_ALIGNMENT_LEFT, 56, 28, Flow.INK)
