extends GutTest
## Drop-in slots stay inert until the paid files arrive: nothing is mapped, no sheets exist, missing voice ids fall back to a tone.

func test_anim_map_has_no_overrides_without_clips() -> void:
	for name in ["idle", "crouch", "L", "2H"]: assert_false(AnimSource.has(name), name)

func test_fx_slots_fall_back_to_the_spark() -> void:
	for id in ["hit_l", "hit_m", "hit_h", "block", "slash", "steam"]:
		assert_true(FxSheet.doc().has(id), id)
	assert_false(FxSheet.exists("hit_l"))

func test_missing_voice_line_plays_tone() -> void:
	var p := Sfx.Pool.new(2); add_child_autofree(p)
	p.play("voice_ko")
	assert_eq(p.players[0].stream, Sfx.tone(), "voice_ko has no file: placeholder tone")
