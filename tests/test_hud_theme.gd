extends GutTest
## The placeholder HUD is driven by one Theme: every control variation the fight scene uses must exist in it.

func test_theme_defines_hud_variations() -> void:
	var t := HudTheme.build()
	for v in ["HudTimer", "HudBanner", "HudInfo", "HudHint", "HealthLow"]:
		assert_true(t.get_type_list().has(v), "theme has %s" % v)
	assert_eq(t.get_font_size("font_size", "HudBanner"), 120)
	assert_ne(t.get_stylebox("fill", "HealthLow"), t.get_stylebox("fill", "ProgressBar"))
