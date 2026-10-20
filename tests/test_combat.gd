extends GutTest
## G1 combat tests: hit and block outcomes, hitstop, advantage, pushback, levels, knockdown, chains, scaling, juggle, throws, buffer.

const L := SimConst.L
const M := SimConst.M
const H := SimConst.H
const S := SimConst.S
const BL := SimConst.BL
const THROW := SimConst.THROW

func _hp1(w: WorldSim) -> bool:
	return w.fighters[1].hp < 1000

# ---------------------------------------------------------------- timing

func test_light_connects_on_startup_plus_one_with_hitstop() -> void:
	var w := TestKit.arena()
	var t := TestKit.first_tick(w, 20, TestKit.tap(0, L), {}, _hp1)
	assert_eq(t, 4, "L startup 4: first active tick is step index 4")
	assert_eq(w.fighters[1].state, "hit")
	assert_eq(w.fighters[1].hp, 970, "damage 30 at 100% scaling")
	assert_eq(w.fighters[0].hitstop, 7)
	assert_eq(w.fighters[1].hitstop, 7)

func _measure_advantage(p2_input: Dictionary) -> int:
	var w := TestKit.arena()
	var att := -1; var def := -1; var stunned := false
	for t in 80:
		w.step([TestKit._at(TestKit.tap(0, L), t), p2_input])
		var d := w.fighters[1]
		if d.state == "hit" or d.state == "blockstun": stunned = true
		if att < 0 and t > 4 and w.fighters[0].actionable(): att = t
		if def < 0 and stunned and d.actionable(): def = t
	return def - att

func test_light_advantage_on_hit_and_block() -> void:
	assert_eq(_measure_advantage(WorldSim.neutral()), 4, "hitstun 11 - 7 remaining = +4")
	assert_eq(_measure_advantage(TestKit.btn(BL)), 1, "blockstun 8 - 7 remaining = +1")

func test_hit_connects_once_per_entry() -> void:
	var w := TestKit.arena()
	TestKit.run(w, 40, TestKit.tap(0, L))
	assert_eq(w.fighters[1].hp, 970, "two active ticks, one hit")

func test_hitstop_freezes_both_but_world_ticks() -> void:
	var w := TestKit.arena()
	TestKit.first_tick(w, 20, TestKit.tap(0, L), {}, _hp1)
	var st0 := [w.fighters[0].st, w.fighters[1].st]
	var tk := w.tick
	for i in 5: w.step([WorldSim.neutral(), WorldSim.neutral()])
	assert_eq([w.fighters[0].st, w.fighters[1].st], st0, "both frozen")
	assert_eq(w.tick, tk + 5, "world keeps counting")

func test_buffered_press_fires_on_first_actionable_tick() -> void:
	var w := TestKit.arena(300)
	var sched := { 0: TestKit.btn(L), 1: WorldSim.neutral(), 9: TestKit.btn(L), 10: WorldSim.neutral() }
	TestKit.run(w, 13, sched)
	assert_eq(w.fighters[0].state, "attack")
	assert_eq(w.fighters[0].st, 1, "second jab starts the tick recovery ends")
	var w2 := TestKit.arena(300)
	TestKit.run(w2, 13, { 0: TestKit.btn(L), 1: WorldSim.neutral(), 5: TestKit.btn(L), 6: WorldSim.neutral() })
	assert_ne(w2.fighters[0].state, "attack", "a press older than 5 ticks expired")

# ---------------------------------------------------------------- blocking and levels

func test_block_prevents_damage_and_sets_blockstun() -> void:
	var w := TestKit.arena()
	TestKit.first_tick(w, 20, TestKit.tap(0, L), TestKit.btn(BL), func(ww: WorldSim) -> bool: return ww.fighters[1].state == "blockstun")
	assert_eq(w.fighters[1].hp, 1000)
	assert_eq(w.fighters[1].hitstop, 5, "blocked hits lose 2 ticks of hitstop")
	assert_eq(w.fighters[1].stun_len, 8)

func test_no_block_without_guard() -> void:
	var w := TestKit.arena()
	TestKit.run(w, 10, TestKit.tap(0, L), WorldSim.neutral())
	assert_lt(w.fighters[1].hp, 1000)

func test_low_needs_crouch_block_mid_needs_either() -> void:
	var low := { 0: TestKit.btn(L, { "down": true }), 1: TestKit.inp({ "down": true }) }
	var w := TestKit.arena()
	TestKit.run(w, 12, low, TestKit.btn(BL))
	assert_lt(w.fighters[1].hp, 1000, "standing guard loses to a low")
	w = TestKit.arena()
	TestKit.run(w, 12, low, TestKit.btn(BL, { "down": true }))
	assert_eq(w.fighters[1].hp, 1000, "crouch guard stops the low")
	assert_eq(w.fighters[1].state, "blockstun")
	w = TestKit.arena()
	TestKit.run(w, 12, TestKit.tap(0, L), TestKit.btn(BL, { "down": true }))
	assert_eq(w.fighters[1].hp, 1000, "crouch guard also stops a mid")

# ---------------------------------------------------------------- pushback

func test_pushback_slides_defender_and_cornered_defender_pushes_attacker() -> void:
	var w := TestKit.arena()
	var x0 := w.fighters[1].x
	TestKit.run(w, 60, TestKit.tap(0, L))
	assert_gt(w.fighters[1].x, x0 + 5.0, "defender slid away")
	assert_lt(w.fighters[1].x, x0 + 14.0, "and the slide decays")
	var c := TestKit.arena()
	c.fighters[0].x = 520.0; c.fighters[1].x = 560.0
	TestKit.run(c, 60, TestKit.tap(0, L))
	assert_eq(c.fighters[1].x, 560.0, "wall holds the defender")
	assert_lt(c.fighters[0].x, 519.0, "attacker is pushed back instead")

# ---------------------------------------------------------------- damage, KO, knockdown

func test_ko_falls_to_the_floor_and_stays_down() -> void:
	var w := TestKit.arena()
	w.fighters[1].hp = 20
	TestKit.run(w, 120, TestKit.tap(0, L))
	assert_eq(w.fighters[1].hp, 0)
	assert_true(w.fighters[1].ko)
	assert_eq(w.fighters[1].state, "ko")
	assert_eq(w.fighters[1].y, 0.0)
	assert_true(w.events.is_empty())

func test_ko_event_emitted_once() -> void:
	var w := TestKit.arena()
	w.fighters[1].hp = 20
	var n := 0
	for t in 60:
		w.step([TestKit._at(TestKit.tap(0, L), t), WorldSim.neutral()])
		for e in w.events: if e.type == "ko": n += 1
	assert_eq(n, 1)

func test_heavy_soft_knockdown_lies_22_then_gets_up_22() -> void:
	var w := TestKit.arena()
	var seen: Array = []
	var peak := { "lying": 0, "getup": 0 }
	for t in 160:
		w.step([TestKit._at(TestKit.tap(0, H), t), WorldSim.neutral()])
		var d := w.fighters[1]
		if seen.is_empty() or seen[-1] != d.state: seen.append(d.state)
		if peak.has(d.state): peak[d.state] = maxi(peak[d.state], d.st)
	assert_eq(seen, ["idle", "launched", "lying", "getup", "idle"])
	assert_eq(peak.lying, 22)
	assert_eq(peak.getup, 22)

func test_wakeup_is_invulnerable_for_three_ticks() -> void:
	var w := TestKit.arena()
	var f := w.fighters[1]
	f.state = "lying"; f.st = 0; f.stun_len = 1
	w.step([WorldSim.neutral(), WorldSim.neutral()]); w.step([WorldSim.neutral(), WorldSim.neutral()])
	assert_eq(f.state, "getup")
	assert_false(f.hittable())
	for i in 3: w.step([WorldSim.neutral(), WorldSim.neutral()])
	assert_true(f.hittable())

func test_lying_fighter_cannot_be_hit() -> void:
	var w := TestKit.arena()
	var f := w.fighters[1]
	f.state = "lying"; f.stun_len = 30
	TestKit.run(w, 15, TestKit.tap(0, H))
	assert_eq(f.hp, 1000)

# ---------------------------------------------------------------- air

func test_air_normal_hits_and_whiff_has_landing_lag() -> void:
	var w := TestKit.arena()
	var a := w.fighters[0]
	a.state = "air"; a.y = 40.0; a.vy = 0.0; a.jump_dir = 0
	TestKit.run(w, 12, TestKit.tap(0, L))
	assert_lt(w.fighters[1].hp, 1000, "jL connects")
	var v := TestKit.arena(250)
	v.fighters[0].state = "air"; v.fighters[0].y = 30.0; v.fighters[0].vy = 0.0
	var lag := 0
	for t in 60:
		v.step([TestKit._at(TestKit.tap(0, L), t), WorldSim.neutral()])
		if v.fighters[0].state == "landlag": lag = maxi(lag, v.fighters[0].st)
	assert_eq(lag, 3, "whiffed air normal: 3 ticks of landing lag")

# ---------------------------------------------------------------- chains and cancels

func _moves_seen(w: WorldSim, n: int, p1: Dictionary, p2 := {}) -> Array:
	var seen: Array = []
	for t in n:
		w.step([TestKit._at(p1, t), TestKit._at(p2, t)])
		var id: String = w.fighters[0].cur.get("id", "")
		if id != "" and (seen.is_empty() or seen[-1] != id): seen.append(id)
	return seen

func test_chain_light_medium_heavy_on_hit() -> void:
	var w := TestKit.arena(30)
	var script := {}
	script.merge(TestKit.tap(0, L)); script.merge(TestKit.tap(10, M)); script.merge(TestKit.tap(25, H))
	assert_eq(_moves_seen(w, 80, script), ["L", "M", "H"])

func test_chain_works_on_block_too() -> void:
	var w := TestKit.arena(30)
	var script := {}
	script.merge(TestKit.tap(0, L)); script.merge(TestKit.tap(8, M))
	assert_eq(_moves_seen(w, 60, script, { 0: TestKit.btn(BL) }), ["L", "M"])

func test_chain_needs_contact() -> void:
	var w := TestKit.arena(300)
	var script := {}
	script.merge(TestKit.tap(0, L)); script.merge(TestKit.tap(6, M))
	assert_eq(_moves_seen(w, 40, script), ["L"], "whiffed jab does not cancel")

func test_same_normal_cannot_repeat_in_a_chain() -> void:
	var w := TestKit.arena(30)
	var script := {}
	script.merge(TestKit.tap(0, L)); script.merge(TestKit.tap(10, L))
	assert_eq(_moves_seen(w, 40, script), ["L"])

func test_heavies_carry_no_chain_cancel() -> void:
	var d := FighterSim.load_data("placeholder")
	assert_false(d.moves.H.cancels.chain)
	assert_false(d.moves["2H"].cancels.chain)
	assert_true(d.moves.L.cancels.chain)

func test_special_cancel_needs_contact() -> void:
	var w := TestKit.arena(30)
	var script := {}
	script.merge(TestKit.tap(0, L)); script.merge(TestKit.tap(10, S))
	assert_eq(_moves_seen(w, 60, script), ["L", "S"], "L cancels into S on hit")
	var whiff := {}
	whiff.merge(TestKit.tap(0, L)); whiff.merge(TestKit.tap(6, S))
	var v := TestKit.arena(300)
	assert_eq(_moves_seen(v, 40, whiff), ["L"], "whiff: no cancel")

func test_crouch_variants_chain() -> void:
	var w := TestKit.arena(30)
	var down := { "down": true }
	var script := { 0: TestKit.btn(L, down), 1: TestKit.inp(down), 10: TestKit.btn(M, down), 11: TestKit.inp(down) }
	assert_eq(_moves_seen(w, 60, script), ["2L", "2M"])

# ---------------------------------------------------------------- scaling, stun decay, juggle

func test_damage_scaling_over_a_combo() -> void:
	var v := FighterSim.new("placeholder", 1, 300.0, -1)
	v.hp = 100000
	var h: Dictionary = v.moves.L.hits[0]
	var got := []
	for i in 8:
		var before := v.hp
		v.receive_hit(h, 1, 1.0)
		got.append(before - v.hp)
	assert_eq(got, [30, 27, 24, 21, 18, 15, 12, 12])
	assert_gte(SimConst.SCALE.min(), SimConst.SCALE_FLOOR)

func test_hitstun_decays_from_hit_four_and_seven() -> void:
	var v := FighterSim.new("placeholder", 1, 300.0, -1)
	v.hp = 100000
	var h: Dictionary = v.moves.L.hits[0]
	var stuns := []
	for i in 7:
		v.receive_hit(h, 1, 1.0)
		stuns.append(v.stun_len)
	assert_eq(stuns, [11, 11, 11, 9, 9, 9, 8])

func test_combo_ends_when_victim_is_actionable() -> void:
	var w := TestKit.arena()
	TestKit.run(w, 6, TestKit.tap(0, L))
	assert_eq(w.fighters[1].combo_hits, 1)
	TestKit.run(w, 60)
	assert_eq(w.fighters[1].combo_hits, 0)

func test_heavy_launches_with_juggle_points_light_costs_one() -> void:
	var w := TestKit.arena()
	TestKit.first_tick(w, 30, TestKit.tap(0, H), {}, _hp1)
	assert_eq(w.fighters[1].state, "launched")
	assert_eq(w.fighters[1].juggle, 3)
	var v := FighterSim.new("placeholder", 1, 300.0, -1)
	v.state = "launched"; v.juggle = 3
	v.receive_hit(v.moves.L.hits[0], 1, 1.0)
	assert_eq(v.juggle, 2)
	v.receive_hit(v.moves.H.hits[0], 1, 1.0)
	assert_eq(v.juggle, 0, "heavy costs 2, floor at 0")

func test_juggle_gate_blocks_hits_when_points_run_out() -> void:
	for pts in [0, 3]:
		var w := TestKit.arena()
		var f := w.fighters[1]
		f.state = "launched"; f.y = 20.0; f.vy = 2.0; f.juggle = pts
		TestKit.run(w, 6, TestKit.tap(0, L))
		if pts == 0: assert_eq(f.hp, 1000, "no points, no hit")
		else: assert_lt(f.hp, 1000, "points left, hit connects")

# ---------------------------------------------------------------- throws

func test_throw_deals_100_hard_knockdown_lies_34() -> void:
	var w := TestKit.arena()
	var peak := { "lying": 0 }
	for t in 160:
		w.step([TestKit._at(TestKit.tap(0, THROW), t), WorldSim.neutral()])
		if w.fighters[1].state == "lying": peak.lying = maxi(peak.lying, w.fighters[1].st)
	assert_eq(w.fighters[1].hp, 900)
	assert_eq(peak.lying, 34)

func test_throw_range_46_connects_47_whiffs() -> void:
	var near := TestKit.arena(46)
	TestKit.run(near, 12, TestKit.tap(0, THROW))
	assert_eq(near.fighters[1].hp, 900)
	var far := TestKit.arena(47)
	TestKit.run(far, 12, TestKit.tap(0, THROW))
	assert_eq(far.fighters[1].hp, 1000)

func test_throw_whiff_locks_attacker_31_ticks() -> void:
	var w := TestKit.arena(200)
	var free := -1
	for t in 60:
		w.step([TestKit._at(TestKit.tap(0, THROW), t), WorldSim.neutral()])
		if free < 0 and t > 2 and w.fighters[0].actionable(): free = t
	assert_eq(free, 31, "5 + 2 + 24 ticks, free on the next")

func test_throw_misses_airborne_and_stunned_defenders() -> void:
	var w := TestKit.arena()
	w.fighters[1].state = "air"; w.fighters[1].y = 30.0; w.fighters[1].vy = 1.0
	TestKit.run(w, 8, TestKit.tap(0, THROW))
	assert_eq(w.fighters[1].hp, 1000)
	var v := TestKit.arena()
	v.fighters[1].state = "hit"; v.fighters[1].stun_len = 60
	TestKit.run(v, 8, TestKit.tap(0, THROW))
	assert_eq(v.fighters[1].hp, 1000)

func test_simultaneous_throws_whiff() -> void:
	var w := TestKit.arena()
	TestKit.run(w, 12, TestKit.tap(0, THROW), TestKit.tap(0, THROW))
	assert_eq(w.fighters[0].hp, 1000)
	assert_eq(w.fighters[1].hp, 1000)

# ---------------------------------------------------------------- trades and determinism

func test_trade_both_fighters_take_hit_and_hitstop() -> void:
	var w := TestKit.arena()
	TestKit.run(w, 6, TestKit.tap(0, L), TestKit.tap(0, L))
	assert_eq(w.fighters[0].hp, 970)
	assert_eq(w.fighters[1].hp, 970)

func test_replay_is_deterministic() -> void:
	var make := func() -> Array:
		var rng := RandomNumberGenerator.new(); rng.seed = 77
		var w := WorldSim.new("placeholder", "placeholder", 5)
		var a := TestKit.pad(rng, 0); var b := TestKit.pad(rng, 1)
		var snaps := []
		for t in 1800:
			w.step([a.call(w), b.call(w)])
			if t % 100 == 0: snaps.append(w.snapshot())
		snaps.append(w.snapshot())
		return snaps
	assert_eq(make.call(), make.call())
