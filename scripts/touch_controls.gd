class_name TouchControls
extends Control
## On-screen controls for touch devices, drawn in the REDLINE HUD style and fed through the same p1_* input actions as the keyboard.
## Left half of the screen: a floating stick (it appears where the thumb lands; left / right walk, up jumps, down crouches).
## Right: the attack buttons L M H S in an arc under the thumb, a small THROW, and a large BLOCK. Top right: pause.
## Shown only on a phone or tablet (Android, iOS, a mobile browser) or when forced with --touch / ?touch=1; --touch also turns mouse clicks into touches for desktop testing.

const FONT := preload("res://assets/fonts/Bangers-Regular.ttf")
const RED := Color("e3262f")
const INK := Color("0a0614")
const STEAM := Color("efe6d2")
const BRASS := Color("c9a14a")
const STICK_R := 96.0
const DEAD := 26.0
const PLAYER := "p1"
const SCREEN := Vector2(1280, 720)
const PAUSE_POS := Vector2(1230, 108)

## id, label, centre, radius, action
const BUTTONS := [
	{ "id": "light", "label": "L", "pos": Vector2(992, 652), "r": 50.0 },
	{ "id": "medium", "label": "M", "pos": Vector2(1032, 557), "r": 50.0 },
	{ "id": "heavy", "label": "H", "pos": Vector2(1115, 495), "r": 50.0 },
	{ "id": "special", "label": "S", "pos": Vector2(1214, 484), "r": 50.0 },
	{ "id": "throw", "label": "T", "pos": Vector2(1140, 628), "r": 36.0 },
	{ "id": "block", "label": "BLOCK", "pos": Vector2(850, 628), "r": 62.0 },
]

var enabled := true : set = _set_enabled
var _mouse := false           # --touch on a desktop: the left mouse button acts as a finger (for testing)
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _btn_touch := {}          # touch index -> button id
var _held := {}               # action -> true while pressed by us

## True on touch devices, or when forced.
static func wanted() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "--touch": return true
	if OS.has_feature("android") or OS.has_feature("ios"): return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"): return true
	if OS.has_feature("web"):
		var js = JavaScriptBridge.eval("((window.matchMedia && matchMedia('(pointer: coarse)').matches) || /[?&]touch=1/.test(location.search)) ? 1 : 0", true)
		return js != null and int(js) == 1
	return false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouse = OS.get_cmdline_user_args().has("--touch")

func _set_enabled(v: bool) -> void:
	enabled = v
	if not v: _release_all()
	queue_redraw()

func _release_all() -> void:
	_stick_id = -1; _btn_touch.clear()
	_sync()

func _input(e: InputEvent) -> void:
	if not enabled: return
	if e is InputEventScreenTouch:
		if e.pressed: _down(e.index, e.position)
		else: _up(e.index)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position)
	elif _mouse and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed: _down(99, e.position)
		else: _up(99)
	elif _mouse and e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		_drag(99, e.position)
	else:
		return
	_sync()
	queue_redraw()

func _button_at(p: Vector2) -> String:
	var best := ""
	var best_d := 1e9
	for b in BUTTONS:
		var d: float = p.distance_to(b.pos)
		if d <= float(b.r) + 14.0 and d < best_d: best = b.id; best_d = d
	return best

func _down(i: int, p: Vector2) -> void:
	if p.distance_to(PAUSE_POS) < 40.0:
		var ev := InputEventAction.new(); ev.action = "pause"; ev.pressed = true
		Input.parse_input_event(ev)
		return
	var b := _button_at(p)
	if b != "":
		_btn_touch[i] = b
	elif p.x < SCREEN.x * 0.5 and _stick_id == -1:
		_stick_id = i; _stick_origin = p; _stick_pos = p

func _up(i: int) -> void:
	if i == _stick_id: _stick_id = -1
	_btn_touch.erase(i)

func _drag(i: int, p: Vector2) -> void:
	if i == _stick_id:
		var d := p - _stick_origin
		if d.length() > STICK_R: _stick_origin = p - d.normalized() * STICK_R     # the base follows a thumb that slides past the rim
		_stick_pos = p
	elif _btn_touch.has(i):
		var b := _button_at(p)
		if b != "": _btn_touch[i] = b
		else: _btn_touch.erase(i)

## Directions the stick currently asks for.
func stick_dirs() -> Dictionary:
	var d := _stick_pos - _stick_origin
	var on := _stick_id != -1
	return { "left": on and d.x < -DEAD, "right": on and d.x > DEAD, "up": on and d.y < -DEAD * 1.3, "down": on and d.y > DEAD * 1.3 }

func _sync() -> void:
	var want := {}
	var dirs := stick_dirs()
	for k in dirs: if dirs[k]: want[k] = true
	for i in _btn_touch: want[_btn_touch[i]] = true
	for a in Controls.ACTIONS:
		var on := want.has(a)
		var name := "%s_%s" % [PLAYER, a]
		if on and not _held.has(a):
			Input.action_press(name); _held[a] = true
		elif not on and _held.has(a):
			Input.action_release(name); _held.erase(a)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not enabled: return
	var pressed := {}
	for i in _btn_touch: pressed[_btn_touch[i]] = true
	for b in BUTTONS:
		var c: Vector2 = b.pos; var r: float = b.r
		var on := pressed.has(b.id)
		draw_circle(c, r + 4.0, Color(INK, 0.55))
		draw_circle(c, r, Color(RED, 0.62) if on else Color(INK, 0.38))
		draw_arc(c, r - 2.0, 0.0, TAU, 40, Color(BRASS, 0.85 if on else 0.55), 4.0)
		var size := 40 if b.label.length() == 1 else 26
		var w := FONT.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(FONT, c + Vector2(-w * 0.5, size * 0.32), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(INK, 0.9))
		draw_string(FONT, c + Vector2(-w * 0.5, size * 0.32), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(STEAM, 0.95))
	# floating stick: a rest hint on the left when idle, the base and knob under the thumb while held
	var o := _stick_origin if _stick_id != -1 else Vector2(210, 570)
	draw_circle(o, STICK_R + 4.0, Color(INK, 0.4))
	draw_arc(o, STICK_R, 0.0, TAU, 56, Color(BRASS, 0.6 if _stick_id != -1 else 0.3), 4.0)
	for k in 4:
		var a := PI * 0.5 * k
		draw_line(o + Vector2(cos(a), sin(a)) * (STICK_R - 18.0), o + Vector2(cos(a), sin(a)) * (STICK_R - 6.0), Color(BRASS, 0.5 if _stick_id != -1 else 0.25), 3.0)
	var knob := o + (_stick_pos - _stick_origin).limit_length(STICK_R) if _stick_id != -1 else o
	draw_circle(knob, 38.0, Color(RED, 0.75) if _stick_id != -1 else Color(INK, 0.35))
	draw_arc(knob, 38.0, 0.0, TAU, 32, Color(STEAM, 0.7 if _stick_id != -1 else 0.35), 3.0)
	draw_circle(PAUSE_POS, 26.0, Color(INK, 0.45))
	draw_arc(PAUSE_POS, 26.0, 0.0, TAU, 28, Color(BRASS, 0.55), 3.0)
	draw_rect(Rect2(1222, 98, 5, 20), Color(STEAM, 0.8)); draw_rect(Rect2(1233, 98, 5, 20), Color(STEAM, 0.8))
