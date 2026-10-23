extends GutTest
## Drop-in slots stay inert until the paid files arrive: nothing is mapped, no sheets exist, missing voice ids fall back to a tone.

func test_anim_map_only_overrides_what_has_a_clip() -> void:
	for name in ["idle", "walk_f", "walk_b", "crouch"]: assert_true(AnimSource.has(name), name)
	for name in ["L", "2H"]: assert_false(AnimSource.has(name), name)

func test_every_mapped_clip_is_in_the_library() -> void:
	for name in AnimSource.doc().map:
		var e: Dictionary = AnimSource.doc().map[name]
		assert_true(AnimSource.library().has_animation(StringName(e.clip)), name)
		if e.has("fast_clip"): assert_true(AnimSource.library().has_animation(StringName(e.fast_clip)), name)

func test_stride_clock_scales_with_ground_speed() -> void:
	var slow := AnimSource.resolve("walk_f", 0.0, 1.0, 0.6)
	var fast := AnimSource.resolve("walk_f", 0.0, 1.0, 1.2)
	assert_eq(slow[0], "ext/Walk_F")
	assert_almost_eq(float(fast[1]), fposmod(float(slow[1]) * 2.0, 1.2), 0.1)
	assert_eq(AnimSource.resolve("walk_f", 0.0, 1.0, 3.0)[0], "ext/Jog_F")
	assert_gt(float(AnimSource.resolve("walk_b", 0.0, 0.1, 1.2)[1]), 1.0)

func test_fx_slots_fall_back_to_the_spark() -> void:
	for id in ["hit_l", "hit_m", "hit_h", "block", "slash", "steam"]:
		assert_true(FxSheet.doc().has(id), id)
	assert_false(FxSheet.exists("hit_l"))

func test_missing_voice_line_plays_tone() -> void:
	var p := Sfx.Pool.new(2); add_child_autofree(p)
	p.play("voice_time")
	assert_eq(p.players[0].stream, Sfx.tone(), "voice_time has no file: placeholder tone")
