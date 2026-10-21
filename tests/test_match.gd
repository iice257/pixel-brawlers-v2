extends GutTest
## Round / match flow tests (MatchSim) plus the seeded soak.

const NEUTRAL := {}

func _n() -> Array:
	return [WorldSim.neutral(), WorldSim.neutral()]

func _to_play(m: MatchSim) -> void:
	var guard := 0
	while m.phase != "play" and guard < 1000:
		m.step(_n()); guard += 1

func _ko_round(m: MatchSim, loser: int) -> void:
	_to_play(m)
	m.world.fighters[loser].hp = 0
	m.step(_n())

func _finish(m: MatchSim) -> void:
	var guard := 0
	while m.phase != "play" and m.phase != "over" and guard < 1000:
		m.step(_n()); guard += 1

func test_intro_call_fight_then_play_timings() -> void:
	var m := MatchSim.new()
	for i in SimConst.INTRO: m.step(_n())
	assert_eq(m.phase, "call")
	for i in SimConst.CALL: m.step(_n())
	assert_eq(m.phase, "fight")
	for i in SimConst.GO: m.step(_n())
	assert_eq(m.phase, "play")

func test_inputs_locked_until_fight() -> void:
	var m := MatchSim.new()
	for i in 30: m.step([TestKit.btn(SimConst.L), WorldSim.neutral()])
	assert_eq(m.phase, "intro")
	assert_eq(m.world.fighters[0].state, "idle", "presses during the intro are ignored")
	assert_false(m.inputs_live())

func test_timer_starts_at_99_and_drops_each_second() -> void:
	var m := MatchSim.new()
	_to_play(m)
	assert_eq(m.seconds_left(), 99)
	for i in 60: m.step(_n())
	assert_eq(m.seconds_left(), 98)

func test_time_over_higher_hp_percentage_wins() -> void:
	var m := MatchSim.new()
	_to_play(m)
	m.world.fighters[0].hp = 500; m.world.fighters[1].hp = 400
	var guard := 0
	while m.round_winner == -2 and guard < 7000:
		m.step(_n()); guard += 1
	assert_eq(m.round_winner, 0)
	assert_eq(m.wins, [1, 0])
	assert_eq(m.phase, "timeup")

func test_time_over_equal_hp_is_a_draw_round_both_score() -> void:
	var m := MatchSim.new()
	_to_play(m)
	var guard := 0
	while m.round_winner == -2 and guard < 7000:
		m.step(_n()); guard += 1
	assert_eq(m.round_winner, -1)
	assert_eq(m.wins, [1, 1])

func test_ko_pacing_normal_108_and_final_154_ticks() -> void:
	var m := MatchSim.new("placeholder", "placeholder", 1, 3)
	_ko_round(m, 1)
	var n := 0
	while m.phase == "ko": n += 1; m.step(_n())
	assert_eq(n, 24 + 24 + 60, "freeze 24, slow-mo 24, post 60 (the KO tick itself counts)")
	assert_eq(m.phase, "call", "round 2 starts with the ROUND call")
	var f := MatchSim.new("placeholder", "placeholder", 1, 1)
	_ko_round(f, 1)
	n = 0
	while f.phase == "ko": n += 1; f.step(_n())
	assert_eq(n, 24 + 40 + 90, "a match-deciding KO is slower")
	assert_eq(f.phase, "over")
	assert_eq(f.match_winner, 0)

func test_slow_motion_steps_world_every_fourth_tick() -> void:
	var m := MatchSim.new()
	_ko_round(m, 1)
	for i in 24: m.step(_n())          # freeze
	var t0 := m.world.tick
	for i in 24: m.step(_n())          # slow-mo
	assert_eq(m.world.tick - t0, 6)

func test_perfect_only_when_winner_untouched() -> void:
	var m := MatchSim.new()
	_ko_round(m, 1)
	assert_true(m.perfect)
	var v := MatchSim.new()
	_to_play(v)
	v.world.fighters[0].hp = 900
	v.world.fighters[1].hp = 0
	v.step(_n())
	assert_false(v.perfect)

func test_double_ko_is_a_draw_round() -> void:
	var m := MatchSim.new()
	_to_play(m)
	m.world.fighters[0].hp = 0; m.world.fighters[1].hp = 0
	m.step(_n())
	assert_eq(m.round_winner, -1)
	assert_eq(m.wins, [1, 1])

func test_between_rounds_full_hp_start_positions_wins_kept() -> void:
	var m := MatchSim.new()
	_to_play(m)
	m.world.fighters[0].x = 400.0
	m.world.fighters[1].hp = 0
	m.step(_n())
	_finish(m)
	assert_eq(m.round_no, 2)
	assert_eq(m.wins, [1, 0])
	assert_eq(m.world.fighters[1].hp, 1000)
	assert_eq(m.world.fighters[0].x, float(SimConst.START_X[0]))
	assert_eq(m.world.fighters[1].x, float(SimConst.START_X[1]))
	assert_eq(m.seconds_left(), 99)

func test_best_of_three_two_wins_end_it() -> void:
	var m := MatchSim.new()
	_ko_round(m, 1); _finish(m)
	assert_ne(m.phase, "over", "one win is not enough")
	_ko_round(m, 1); _finish(m)
	assert_eq(m.phase, "over")
	assert_eq(m.match_winner, 0)

func test_draw_then_win_in_best_of_three() -> void:
	var m := MatchSim.new()
	_to_play(m)
	m.world.fighters[0].hp = 0; m.world.fighters[1].hp = 0
	m.step(_n()); _finish(m)
	assert_eq(m.wins, [1, 1])
	assert_ne(m.phase, "over", "1-1 after a draw: play on")
	_ko_round(m, 1); _finish(m)
	assert_eq(m.wins, [2, 1])
	assert_eq(m.match_winner, 0)

func test_two_draws_end_a_best_of_three_as_a_draw() -> void:
	var m := MatchSim.new()
	for i in 2:
		_to_play(m)
		m.world.fighters[0].hp = 0; m.world.fighters[1].hp = 0
		m.step(_n()); _finish(m)
	assert_eq(m.phase, "over")
	assert_eq(m.match_winner, -1)

func test_winner_plays_win_pose_loser_stays_down() -> void:
	var m := MatchSim.new()
	_to_play(m)
	m.world.fighters[1].hp = 20
	m.world.fighters[0].x = 268.0; m.world.fighters[1].x = 308.0
	m.step([TestKit.btn(SimConst.L), WorldSim.neutral()])
	while m.phase == "play": m.step(_n())
	var guard := 0
	while m.phase == "ko" and m.pt < 24 + 24 + 55 and guard < 500: m.step(_n()); guard += 1
	assert_eq(m.world.fighters[0].state, "win")
	assert_eq(m.world.fighters[1].state, "ko")

func test_match_snapshot_is_deterministic() -> void:
	var make := func() -> Dictionary:
		var rng := RandomNumberGenerator.new(); rng.seed = 11
		var m := MatchSim.new("placeholder", "placeholder", 3, 3)
		var a := TestKit.pad(rng, 0); var b := TestKit.pad(rng, 1)
		for t in 1500: m.step([a.call(m.world), b.call(m.world)])
		return m.snapshot()
	assert_eq(make.call(), make.call())

# ---------------------------------------------------------------- soak

func _sane(f: FighterSim) -> bool:
	return is_finite(f.x) and is_finite(f.y) and is_finite(f.vx) and is_finite(f.vy) and is_finite(f.kb) and f.hp >= 0 and f.hp <= 1000

func test_soak_seeded_random_matches_finish_without_nan() -> void:
	# Quick pass by default; SOAK_MATCHES=200 (tools/soak.sh) runs the full soak.
	var count := maxi(int(OS.get_environment("SOAK_MATCHES")), 12)
	var worst := 0
	var hits := 0
	var finished := 0
	for n in count:
		var rng := RandomNumberGenerator.new(); rng.seed = 1000 + n
		var m := MatchSim.new("placeholder", "placeholder", n + 1, [1, 3, 3, 5][n % 4])
		var a := TestKit.pad(rng, 0); var b := TestKit.pad(rng, 1)
		var t := 0
		while t < 60000 and m.phase != "over":
			m.step([a.call(m.world), b.call(m.world)])
			t += 1
			for e in m.world.events: if e.type == "hit": hits += 1
			if not (_sane(m.world.fighters[0]) and _sane(m.world.fighters[1])):
				fail_test("match %d tick %d: bad state %s" % [n, t, m.world.snapshot()])
				return
		if m.phase == "over": finished += 1
		worst = maxi(worst, t)
	gut.p("soak: %d matches, %d finished, %d hits, longest %d ticks" % [count, finished, hits, worst])
	assert_eq(finished, count, "every match reaches the end")
	assert_gt(hits, count * 4, "the random pads actually fight")
