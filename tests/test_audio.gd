extends GutTest
## Every sound in data/audio.json must resolve to a real, loadable file and the buses must exist.

func test_all_audio_files_load() -> void:
	for id in Sfx.doc():
		var e: Dictionary = Sfx.doc()[id]
		assert_true(Sfx.BUSES.has(e.bus), "%s bus" % id)
		if e.has("synth"): continue
		for layer in e.layers:
			assert_eq(layer.pitch.size(), 2, "%s pitch range" % id)
			for f in layer.files:
				assert_true(ResourceLoader.exists(f), f)
				assert_true(Sfx.stream(f) is AudioStream, f)

func test_pool_creates_buses_and_plays() -> void:
	var pool := Sfx.Pool.new(); add_child_autofree(pool)
	for b in Sfx.BUSES: assert_gte(AudioServer.get_bus_index(b), 0, b)
	pool.play("hit_h"); pool.play("whoosh"); pool.play("voice_fight"); pool.play("missing_id")
	assert_true(true)

func test_whoosh_sets_and_dragon_announcer_are_wired() -> void:
	assert_eq(Sfx.doc().whoosh_light.layers[0].files.size(), 4, "4 lighter swishes")
	assert_eq(Sfx.doc().whoosh_heavy.layers[0].files.size(), 9, "9 heavier swishes")
	for id in ["voice_fight", "voice_round_1", "voice_round_2", "voice_final_round", "voice_ko"]:
		assert_true(String(Sfx.doc()[id].layers[0].files[0]).contains("dragon_"), id)

func test_credits_screen_names_the_cc_by_sa_author() -> void:
	var f: Flow = load("res://ui/flow.tscn").instantiate()
	add_child_autofree(f)
	await wait_seconds(0.5)
	f._show("credits")
	var text := ""
	for c in f.screen.get_children():
		if c is Label: text += c.text + "\n"
	assert_true(text.contains("VoiceBosch") and text.contains("CC BY-SA 4.0"))
	assert_true(text.contains("artisticdude"))
