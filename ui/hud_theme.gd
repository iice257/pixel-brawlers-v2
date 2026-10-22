class_name HudTheme
extends RefCounted
## Placeholder HUD look in one Theme: health bars (ProgressBar), the round timer and banner (Label variations), the info line.
## Controls pick a look with theme_type_variation, so changing the art later means editing only this file.
const GOLD := Color("ffcf33")
const RED := Color("e3262f")          # REDLINE brand red
const BRASS := Color("c9a14a")
const INK := Color("0a0614")
const CREAM := Color("fff0a0")
const STEAM := Color("efe6d2")
const DIM := Color("8a80b0")
const FRAME_DIR := "res://assets/ui/"   # drop <name>.png here (button_normal, button_focus) and it replaces the flat style, no code change
const FRAME_MARGIN := 24                # 9-slice margin for those textures

static func _box(c: Color, border := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_border_width_all(border)
	s.border_color = INK
	s.set_content_margin_all(border)
	return s

## Flat style for a control state, or a 9-slice texture box when assets/ui/<name>.png exists.
static func _frame(name: String, flat: StyleBox) -> StyleBox:
	var path := FRAME_DIR + name + ".png"
	if ResourceLoader.exists(path):
		var tb := StyleBoxTexture.new()
		tb.texture = load(path)
		tb.set_texture_margin_all(FRAME_MARGIN); tb.set_content_margin_all(14)
		return tb
	return flat

## Brass plate with ink outline; the focused one gets a thick red bar on the left and a bright face.
static func _plate(face: Color, bar_w := 0) -> StyleBoxFlat:
	var s := _box(face, 3)
	s.border_width_left = 3 + bar_w
	s.set_corner_radius_all(2)
	s.set_content_margin_all(14)
	s.content_margin_left = 22
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_font_size("font_size", "Label", 14)
	t.set_stylebox("background", "ProgressBar", _box(INK, 3))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD))
	t.add_type("HealthLow"); t.set_type_variation("HealthLow", "ProgressBar")
	t.set_stylebox("background", "HealthLow", _box(INK, 3))
	t.set_stylebox("fill", "HealthLow", _box(RED))
	for v in [["HudTimer", 52, Color.WHITE], ["HudBanner", 72, CREAM], ["HudInfo", 14, GOLD], ["HudHint", 14, DIM]]:
		t.add_type(v[0]); t.set_type_variation(v[0], "Label")
		t.set_font_size("font_size", v[0], v[1])
		t.set_color("font_color", v[0], v[2])
	t.set_color("font_outline_color", "HudBanner", INK); t.set_constant("outline_size", "HudBanner", 28)
	t.set_font_size("font_size", "HudBanner", 120)
	t.set_font("font", "HudBanner", load("res://assets/fonts/Bangers-Regular.ttf"))   # OFL display face, see docs/ASSETS.md
	t.set_font("font", "HudTimer", load("res://assets/fonts/Bangers-Regular.ttf"))
	var plain := _plate(BRASS)
	var lit := _plate(STEAM, 10)
	lit.border_color = RED
	t.set_stylebox("normal", "Button", _frame("button_normal", plain))
	for st in ["hover", "pressed", "focus"]: t.set_stylebox(st, "Button", _frame("button_focus", lit))
	t.set_stylebox("disabled", "Button", _frame("button_normal", plain))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: t.set_color(c, "Button", INK)
	t.set_font("font", "Button", load("res://assets/fonts/Bangers-Regular.ttf"))
	t.set_font_size("font_size", "Button", 38)
	return t
