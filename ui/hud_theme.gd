class_name HudTheme
extends RefCounted
## Placeholder HUD look in one Theme: health bars (ProgressBar), the round timer and banner (Label variations), the info line.
## Controls pick a look with theme_type_variation, so changing the art later means editing only this file.
const GOLD := Color("ffcf33")
const RED := Color("ff4a4a")
const INK := Color("0a0614")
const CREAM := Color("fff0a0")
const DIM := Color("8a80b0")

static func _box(c: Color, border := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_border_width_all(border)
	s.border_color = INK
	s.set_content_margin_all(border)
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
	for v in [["HudTimer", 40, Color.WHITE], ["HudBanner", 72, CREAM], ["HudInfo", 14, GOLD], ["HudHint", 14, DIM]]:
		t.add_type(v[0]); t.set_type_variation(v[0], "Label")
		t.set_font_size("font_size", v[0], v[1])
		t.set_color("font_color", v[0], v[2])
	return t
