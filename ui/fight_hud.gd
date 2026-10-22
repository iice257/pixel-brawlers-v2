class_name FightHud
extends Control
## REDLINE fight HUD, drawn in code: brass pressure-tube health bars (soot fill teal -> hot red as HP drops, white chip-damage trail),
## round pips and Bangers names under the bars, the timer in a gauge dial, and a "3 HITS" counter that punches in.
## Slots: drop assets/ui/hud_bar.png (bar frame, 520x34), hud_dial.png (dial face, 128x128) or hud_pip.png (32x32, two frames side by side:
## empty | won) and that element is drawn from the texture instead of the procedural shape; fills, needle and text stay live.

const FONT := preload("res://assets/fonts/Bangers-Regular.ttf")
const UI := "res://assets/ui/"
const BAR_W := 520.0
const BAR_H := 30.0
const BAR_Y := 26.0
const MARGIN := 40.0
const TEAL := Color("3fe0d0")
const HOT := Color("ff2a2a")
const BRASS := Color("c9a14a")
const BRASS_DK := Color("7a5b22")
const SOOT := Color("15101c")
const INK := Color("0a0614")
const STEAM := Color("efe6d2")

var names := ["P1", "P2"]
var pct := [1.0, 1.0]
var chip := [1.0, 1.0]
var chip_hold := [0.0, 0.0]
var wins := [0, 0]
var need := 2
var seconds := 99
var round_seconds := 99
var combo := [0, 0]            # hits the fighter on that side has landed in the current combo
var combo_pop := [0.0, 0.0]
var combo_fade := [0.0, 0.0]
var combo_shown := [0, 0]
var _tex := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for n in ["hud_bar", "hud_dial", "hud_pip"]:
		if ResourceLoader.exists(UI + n + ".png"): _tex[n] = load(UI + n + ".png")

## Called every frame with the sim values; dt drives the chip trail and the combo pop.
func update_state(p: Array, secs: int, w: Array, hits: Array, dt: float) -> void:
	for i in 2:
		if p[i] < pct[i] - 0.0001: chip_hold[i] = 0.45       # fresh damage: the white trail waits, then drains
		pct[i] = p[i]
		if chip_hold[i] > 0.0: chip_hold[i] -= dt
		elif chip[i] > pct[i]: chip[i] = maxf(pct[i], chip[i] - dt * 0.7)
		if chip[i] < pct[i]: chip[i] = pct[i]
		if hits[i] >= 2:
			if hits[i] != combo_shown[i]: combo_pop[i] = 1.0
			combo_shown[i] = hits[i]; combo_fade[i] = 1.0
		else:
			combo_fade[i] = maxf(0.0, combo_fade[i] - dt * 1.4)
			if combo_fade[i] <= 0.0: combo_shown[i] = 0
		combo_pop[i] = maxf(0.0, combo_pop[i] - dt * 7.0)
	seconds = secs; wins = w
	queue_redraw()

func reset_state() -> void:
	pct = [1.0, 1.0]; chip = [1.0, 1.0]; combo_shown = [0, 0]; combo_fade = [0.0, 0.0]

func _bar_rect(i: int) -> Rect2:
	return Rect2(MARGIN if i == 0 else 1280.0 - MARGIN - BAR_W, BAR_Y, BAR_W, BAR_H)

func _draw() -> void:
	for i in 2: _bar(i)
	_dial(Vector2(640, BAR_Y + BAR_H * 0.5 + 6))
	for i in 2: _combo(i)

func _bar(i: int) -> void:
	var r := _bar_rect(i)
	var inner := r.grow(-5)
	draw_rect(r.grow(3), INK)
	draw_rect(inner, SOOT)
	var left := i == 0
	_fill(inner, chip[i], Color("f4f1e6"), left)
	var col := TEAL.lerp(HOT, clampf((0.5 - pct[i]) / 0.4, 0.0, 1.0))
	_fill(inner, pct[i], col, left)
	var fr := Rect2(inner.position, Vector2(inner.size.x * pct[i], inner.size.y))
	if not left: fr.position.x = inner.end.x - fr.size.x
	if fr.size.x > 2.0: draw_rect(Rect2(fr.position + Vector2(0, 2), Vector2(fr.size.x, 3)), Color(1, 1, 1, 0.28))
	if _tex.has("hud_bar"):
		draw_texture_rect(_tex.hud_bar, r.grow(8), false)
	else:
		draw_rect(r, BRASS, false, 5.0)
		draw_rect(r.grow(-2.5), BRASS_DK, false, 1.5)
		for k: float in [0.25, 0.5, 0.75]:
			var x := inner.position.x + inner.size.x * k
			draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(INK, 0.6), 2.0)
		for end in [r.position.x, r.end.x]:                          # riveted end caps
			draw_circle(Vector2(end, r.get_center().y), 6.0, BRASS); draw_arc(Vector2(end, r.get_center().y), 6.0, 0, TAU, 14, INK, 2.0)
	# name at the outer edge, pips on the inner side, both under the tube
	var nm: String = names[i]
	var ny := r.end.y + 34.0
	if left: draw_string_outline(FONT, Vector2(r.position.x, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, INK)
	else: draw_string_outline(FONT, Vector2(r.end.x - 300.0, ny), nm, HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 30, 8, INK)
	if left: draw_string(FONT, Vector2(r.position.x, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, STEAM)
	else: draw_string(FONT, Vector2(r.end.x - 300.0, ny), nm, HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 30, STEAM)
	for k in need:
		var x: float = (r.end.x - 14.0 - k * 26.0) if left else (r.position.x + 14.0 + k * 26.0)
		_pip(Vector2(x, r.end.y + 20.0), k < wins[i])

func _fill(inner: Rect2, v: float, c: Color, left: bool) -> void:
	var w := inner.size.x * v
	if w <= 0.5: return
	draw_rect(Rect2(inner.position.x if left else inner.end.x - w, inner.position.y, w, inner.size.y), c)

func _pip(p: Vector2, won: bool) -> void:
	if _tex.has("hud_pip"):
		var t: Texture2D = _tex.hud_pip; var hw := t.get_width() * 0.5
		draw_texture_rect_region(t, Rect2(p - Vector2(hw, t.get_height()) * 0.5, Vector2(hw, t.get_height())), Rect2(hw if won else 0.0, 0, hw, t.get_height()))
		return
	draw_circle(p, 10.0, INK)
	draw_circle(p, 7.5, Color("e3262f") if won else SOOT)
	draw_arc(p, 8.5, 0, TAU, 20, BRASS, 2.0)

func _dial(c: Vector2) -> void:
	var rad := 46.0
	if _tex.has("hud_dial"):
		draw_texture_rect(_tex.hud_dial, Rect2(c - Vector2(64, 64), Vector2(128, 128)), false)
	else:
		draw_circle(c, rad + 7.0, INK); draw_circle(c, rad + 3.0, BRASS); draw_circle(c, rad - 3.0, BRASS_DK); draw_circle(c, rad - 6.0, SOOT)
		for k in 24:
			var a := TAU * k / 24.0 - PI * 0.5
			var l := 7.0 if k % 6 == 0 else 4.0
			draw_line(c + Vector2(cos(a), sin(a)) * (rad - 7.0), c + Vector2(cos(a), sin(a)) * (rad - 7.0 - l), Color(STEAM, 0.75), 2.0)
		draw_arc(c, rad - 9.0, -PI * 0.5 - TAU * 0.1, -PI * 0.5, 12, Color("e3262f"), 4.0)    # the last 10 % is the red zone
	var f := clampf(float(seconds) / float(maxi(round_seconds, 1)), 0.0, 1.0)
	var a := -PI * 0.5 - TAU * (1.0 - f)
	draw_line(c, c + Vector2(cos(a), sin(a)) * (rad - 12.0), Color("e3262f"), 3.0)
	draw_circle(c, 4.0, BRASS)
	var txt := "%02d" % seconds
	var col := Color("ff5a4a") if seconds <= 10 else STEAM
	draw_string_outline(FONT, c + Vector2(-40, 15), txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 46, 8, INK)
	draw_string(FONT, c + Vector2(-40, 15), txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 46, col)

func _combo(i: int) -> void:
	if combo_shown[i] < 2 or combo_fade[i] <= 0.0: return
	var left := i == 0
	var k: float = 1.0 + 0.4 * combo_pop[i] * combo_pop[i]
	var a := clampf(combo_fade[i] * 2.0, 0.0, 1.0)
	var origin := Vector2(MARGIN + 6.0 if left else 1280.0 - MARGIN - 6.0, 262.0)
	draw_set_transform(origin, -0.08 if left else 0.08, Vector2(k, k))
	var al := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	var x: float = 0.0 if left else -320.0
	draw_string_outline(FONT, Vector2(x, 0), str(combo_shown[i]), al, 320.0, 96, 14, Color(INK, a))
	draw_string(FONT, Vector2(x, 0), str(combo_shown[i]), al, 320.0, 96, Color(Color("e3262f"), a))
	var num_w := FONT.get_string_size(str(combo_shown[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	var tx: float = num_w + 10.0 if left else -num_w - 10.0 - 140.0
	draw_string_outline(FONT, Vector2(tx, -6), "HITS", HORIZONTAL_ALIGNMENT_LEFT, 140.0, 44, 10, Color(INK, a))
	draw_string(FONT, Vector2(tx, -6), "HITS", HORIZONTAL_ALIGNMENT_LEFT, 140.0, 44, Color(STEAM, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
