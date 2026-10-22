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
