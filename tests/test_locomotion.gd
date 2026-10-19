extends GutTest
## G0 sim tests: locomotion, spacing rules, determinism, animation contract.

const N := { "left": false, "right": false, "up": false, "down": false, "buttons": 0 }

func _in(o: Dictionary) -> Dictionary:
	var i := N.duplicate(); i.merge(o, true); return i

func _run(w: WorldSim, n: int, a: Dictionary = N, b: Dictionary = N) -> void:
	for t in n: w.step([a, b])

func test_walk_forward_and_back_speeds() -> void:
	var w := WorldSim.new()
	var x0 := w.fighters[0].x
	_run(w, 10, _in({ "right": true }))
	assert_almost_eq(w.fighters[0].x - x0, 10 * 2.1, 0.001, "walk_f = 2.1 px/tick")
	assert_eq(w.fighters[0].state, "walk_f")
	var x1 := w.fighters[0].x
	_run(w, 10, _in({ "left": true }))
	assert_almost_eq(x1 - w.fighters[0].x, 10 * 1.7, 0.001, "walk_b = 1.7 px/tick")
	assert_eq(w.fighters[0].state, "walk_b")

func test_socd_left_right_is_neutral() -> void:
	var w := WorldSim.new()
	_run(w, 5, _in({ "left": true, "right": true }))
	assert_eq(w.fighters[0].state, "idle")

func test_jump_arc_lands() -> void:
	var w := WorldSim.new()
	var f := w.fighters[0]
	w.step([_in({ "up": true }), N])
	assert_eq(f.state, "prejump")
	var peak := 0.0; var airborne := 0
	for t in 120:
		w.step([N, N])
		if f.state == "air": airborne += 1
		peak = maxf(peak, f.y)
		if airborne > 0 and f.state == "idle": break
	assert_eq(f.state, "idle", "lands")
	assert_eq(f.y, 0.0)
	assert_between(peak, 70.0, 82.0, "apex ~ vy^2 / 2g")
	assert_between(airborne, 36, 42, "~39 ticks airborne")

func test_forward_jump_travels_toward_opponent() -> void:
	var w := WorldSim.new()
	var x0 := w.fighters[0].x
	w.step([_in({ "up": true, "right": true }), N])
	_run(w, 20)
	assert_eq(w.fighters[0].anim(), "jump_f")
	assert_gt(w.fighters[0].x, x0)

func test_push_boxes_never_overlap() -> void:
	var w := WorldSim.new()
	for t in 200:   # grounded bodies: hard separation every tick
		w.step([_in({ "right": true }), _in({ "left": true })])
		assert_false(w.fighters[0].push_box().intersects(w.fighters[1].push_box()), "tick %d" % t)
		if is_failing(): return

func test_facing_turns_after_crossing_jump() -> void:
	var w := WorldSim.new()
	w.fighters[0].x = 300; w.fighters[1].x = 330
	w.step([_in({ "up": true, "right": true }), N])
	_run(w, 60)
	assert_gt(w.fighters[0].x, w.fighters[1].x, "crossed over")
	assert_eq(w.fighters[0].facing, -1)
	assert_eq(w.fighters[1].facing, 1)

func test_stage_clamp_and_max_separation() -> void:
	var w := WorldSim.new()
	_run(w, 400, _in({ "left": true }), _in({ "right": true }))
	var a := w.fighters[0]; var b := w.fighters[1]
	assert_true(absf(b.x - a.x) <= SimConst.MAX_SEP + 0.001)
	assert_true(a.x >= SimConst.STAGE_MIN and b.x <= SimConst.STAGE_MAX)

func test_deterministic() -> void:
	var make := func() -> Dictionary:
		var w := WorldSim.new("placeholder", "placeholder", 7)
		var rng := RandomNumberGenerator.new(); rng.seed = 99
		for t in 600:
			var r := func() -> Dictionary: return { "left": rng.randf() < 0.3, "right": rng.randf() < 0.4, "up": rng.randf() < 0.05, "down": rng.randf() < 0.1, "buttons": 0 }
			w.step([r.call(), r.call()])
		return w.snapshot()
	assert_eq(make.call(), make.call())

func test_placeholder_meets_anim_contract() -> void:
	var map := AnimMap.load_for("placeholder")
	var moves: Array = FighterSim.load_data("placeholder").moves
	assert_eq(AnimContract.missing(map, moves), [])
