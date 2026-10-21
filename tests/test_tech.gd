extends GutTest
## G1: hit levels (overhead / low / mid) against stand and crouch guard, the 2H sweep, and the throw tech rules from TUNING_LOG 2.5.

const L := SimConst.L
const H := SimConst.H
const BL := SimConst.BL
const THROW := SimConst.THROW

# ---------------------------------------------------------------- levels

## P1 hits P2 with `move` from the air (jL / jM / jH use the same setup); P2 guards standing or crouching.
func _air_hit(button: int, crouch_guard: bool) -> WorldSim:
	var w := TestKit.arena()
	var a := w.fighters[0]
	a.state = "air"; a.y = 40.0; a.vy = 0.0; a.jump_dir = 0
	TestKit.run(w, 14, TestKit.tap(0, button), TestKit.btn(BL, { "down": crouch_guard }))
	return w

func test_overhead_beats_crouch_guard() -> void:
	for b in [L, SimConst.M, H]:
		assert_lt(_air_hit(b, true).fighters[1].hp, 1000, "jump attack %d hits a crouch block" % b)

func test_overhead_is_blocked_standing() -> void:
	for b in [L, SimConst.M, H]:
		var w := _air_hit(b, false)
		assert_eq(w.fighters[1].hp, 1000, "jump attack %d blocked standing" % b)
		assert_eq(w.fighters[1].state, "blockstun")

func test_all_jump_attacks_are_overhead_in_data() -> void:
	var d := FighterSim.load_data("placeholder")
	for id in ["jL", "jM", "jH"]: assert_eq(d.moves[id].hits[0].level, "overhead", id)

func test_low_hits_a_standing_guard_and_is_blocked_crouching() -> void:
	var low := { 0: TestKit.btn(L, { "down": true }), 1: TestKit.inp({ "down": true }) }
	var w := TestKit.arena()
	TestKit.run(w, 12, low, TestKit.btn(BL))
	assert_lt(w.fighters[1].hp, 1000, "low vs stand block = hit")
	w = TestKit.arena()
	TestKit.run(w, 12, low, TestKit.btn(BL, { "down": true }))
	assert_eq(w.fighters[1].hp, 1000, "low vs crouch block = block")

func test_2h_is_a_low_sweep_with_hard_knockdown() -> void:
	var m: Dictionary = FighterSim.load_data("placeholder").moves["2H"]
	assert_eq(m.hits[0].level, "low")
	assert_eq(m.hits[0].kd, "hard")
	var w := TestKit.arena()
	var lie := 0
	for t in 120:
		w.step([TestKit._at({ 0: TestKit.btn(H, { "down": true }), 1: WorldSim.neutral() }, t), WorldSim.neutral()])
		if w.fighters[1].state == "lying": lie = maxi(lie, w.fighters[1].st)
	assert_eq(lie, SimConst.LIE_HARD, "sweep knocks down hard")
	var g := TestKit.arena()
	TestKit.run(g, 20, { 0: TestKit.btn(H, { "down": true }) }, TestKit.btn(BL, { "down": true }))
	assert_eq(g.fighters[1].hp, 1000, "crouch guard stops the sweep")
	assert_eq(g.fighters[1].state, "blockstun")
	var blk: Dictionary = m.hits[0]
	assert_eq(FrameData.derive(m).adv_block, -9)

# ---------------------------------------------------------------- throw tech

## P1 throws on tick 0. P2 presses Throw `tech_after` ticks after the grab connects (-1 = never). Returns { w, grab, events }.
func _throw(tech_after: int, p2_tap_too := false) -> Dictionary:
	var w := TestKit.arena()
	var grab := -1
	var log := []
	for t in 60:
		var p2 := WorldSim.neutral()
		if grab >= 0 and tech_after >= 0 and t == grab + tech_after: p2 = TestKit.btn(THROW)
		w.step([TestKit._at(TestKit.tap(0, THROW), t), p2])
		for e in w.events:
			log.append([t, e.type])
			if e.type == "grab" and grab < 0: grab = t
	return { "w": w, "grab": grab, "log": log }

func _types(r: Dictionary) -> Array:
	return r.log.map(func(e): return e[1])

func test_grab_does_no_damage_until_tick_8() -> void:
	var w := TestKit.arena()
	var grab := -1
	for t in 60:
		w.step([TestKit._at(TestKit.tap(0, THROW), t), WorldSim.neutral()])
		if grab < 0 and w.events.any(func(e): return e.type == "grab"): grab = t
		if grab >= 0 and t == grab + 7: assert_eq(w.fighters[1].hp, 1000, "no damage through tick 7")
		if grab >= 0 and t == grab + 8: assert_eq(w.fighters[1].hp, 900, "100 damage lands on tick 8")
	assert_true(grab > 0)

func test_tech_at_tick_7_succeeds() -> void:
	var r := _throw(7)
	assert_true(_types(r).has("tech"))
	assert_false(_types(r).has("throw"), "no damage event")
	assert_eq(r.w.fighters[1].hp, 1000)
	assert_eq(r.w.fighters[0].hp, 1000)

func test_tech_at_tick_8_fails() -> void:
	var r := _throw(8)
	assert_false(_types(r).has("tech"))
	assert_eq(r.w.fighters[1].hp, 900)

func test_tech_on_first_tick_succeeds() -> void:
	assert_true(_types(_throw(1)).has("tech"))

func test_tech_pushes_both_apart_then_both_are_neutral() -> void:
	var r := _throw(3)
	var w: WorldSim = r.w
	assert_gte(absf(w.fighters[1].x - w.fighters[0].x), 40.0 + 20.0, "pushed at least 20 px further apart")
	assert_eq(w.fighters[0].state, "idle", "attacker neutral again")
	assert_eq(w.fighters[1].state, "idle", "defender neutral again")

func test_only_the_throw_button_techs() -> void:
	var w := TestKit.arena()
	var grab := -1
	for t in 60:
		var p2 := WorldSim.neutral()
		if grab >= 0 and t >= grab + 1 and t <= grab + 7: p2 = TestKit.btn(L | SimConst.M | H | BL)
		w.step([TestKit._at(TestKit.tap(0, THROW), t), p2])
		if grab < 0 and w.events.any(func(e): return e.type == "grab"): grab = t
	assert_eq(w.fighters[1].hp, 900, "other buttons do not tech")

func test_simultaneous_throws_tech_each_other() -> void:
	var w := TestKit.arena()
	var log := []
	for t in 40:
		w.step([TestKit._at(TestKit.tap(0, THROW), t), TestKit._at(TestKit.tap(0, THROW), t)])
		for e in w.events: log.append(e.type)
	assert_true(log.has("tech"))
	assert_false(log.has("grab"))
	assert_eq(w.fighters[0].hp, 1000)
	assert_eq(w.fighters[1].hp, 1000)
	assert_gt(absf(w.fighters[1].x - w.fighters[0].x), 60.0, "pushed apart")

func test_throw_tech_is_deterministic() -> void:
	var a := _throw(5)
	var b := _throw(5)
	assert_eq(a.log, b.log)
	for i in 2:
		assert_eq(a.w.fighters[i].x, b.w.fighters[i].x)
		assert_eq(a.w.fighters[i].hp, b.w.fighters[i].hp)
		assert_eq(a.w.fighters[i].state, b.w.fighters[i].state)
