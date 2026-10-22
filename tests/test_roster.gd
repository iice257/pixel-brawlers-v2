extends GutTest
## Roster: KESTREL (rushdown) and BRIGGS (grappler) differ in data and in the sim: dashes, the hop step, armour, the command grab.

const L := SimConst.L
const H := SimConst.H
const S := SimConst.S
const BL := SimConst.BL
const THROW := SimConst.THROW

func _world(p1: String, p2: String, gap := 40.0) -> WorldSim:
	var w := WorldSim.new(p1, p2, 1)
	w.fighters[0].x = 288.0 - gap / 2.0
	w.fighters[1].x = 288.0 + gap / 2.0
	return w

## Press-release-press of one direction (P1 faces right: "right" is forward).
func _double_tap(dir_key: String) -> Dictionary:
	return { 0: TestKit.inp({ dir_key: true }), 1: WorldSim.neutral(), 2: TestKit.inp({ dir_key: true }), 10: WorldSim.neutral() }

func _walk_only(dir_key: String) -> Dictionary:
	return { 0: TestKit.inp({ dir_key: true }), 10: WorldSim.neutral() }

# ---------------------------------------------------------------- data

func test_stats_and_tags_come_from_data() -> void:
	var k := FighterSim.load_data("kestrel")
	var b := FighterSim.load_data("briggs")
	assert_eq(int(k.stats.hp), 900)
	assert_eq(int(b.stats.hp), 1150)
	assert_eq(k.tag, "DUELLIST")
	assert_eq(b.tag, "BRAWLER")
	assert_gt(k.stats.walk_f, b.stats.walk_f, "KESTREL walks faster")
	assert_true(k.stats.has("dash"))
	assert_false(b.stats.has("dash"), "BRIGGS has no dash")
	assert_true(b.stats.has("hop"))
	assert_eq(_world("kestrel", "briggs").fighters[1].hp, 1150)

func test_briggs_has_own_body_boxes() -> void:
	var k := _world("kestrel", "briggs").fighters
	assert_gt(k[1].push_box().size.x, 0.0)
	assert_gt(k[1].hurt_boxes()[0].size.y + k[1].hurt_boxes()[1].size.y, 0.0)
	assert_ne(k[0].boxes, k[1].boxes, "per-fighter boxes")

# ---------------------------------------------------------------- dashes

func test_forward_double_tap_dashes_further_than_walking() -> void:
	var w := _world("kestrel", "briggs", 300.0)
	var x0: float = w.fighters[0].x
	var saw := false
	for t in 30:
		w.step([TestKit._at(_double_tap("right"), t), WorldSim.neutral()])
		if w.fighters[0].state == "dash": saw = true
	var dashed: float = w.fighters[0].x - x0
	var v := _world("kestrel", "briggs", 300.0)
	TestKit.run(v, 30, _walk_only("right"))
	assert_true(saw, "enters the dash state")
	assert_gt(dashed, (v.fighters[0].x - x0) + 20.0, "dash covers more ground than a walk")

func test_backdash_is_invulnerable_and_moves_back() -> void:
	var w := _world("kestrel", "briggs", 300.0)
	var x0: float = w.fighters[0].x
	var inv := false
	for t in 30:
		w.step([TestKit._at(_double_tap("left"), t), WorldSim.neutral()])
		if w.fighters[0].state == "dash" and w.fighters[0].invuln > 0: inv = true
	assert_true(inv, "invulnerable early in the backdash")
	assert_lt(w.fighters[0].x, x0 - 20.0)

func test_briggs_double_tap_is_a_hop_not_a_dash() -> void:
	var w := _world("briggs", "kestrel", 300.0)
	var air := false
	var dash := false
	var x0: float = w.fighters[0].x
	for t in 40:
		w.step([TestKit._at(_double_tap("right"), t), WorldSim.neutral()])
		if w.fighters[0].state == "air": air = true
		if w.fighters[0].state == "dash": dash = true
	assert_true(air, "short hop")
	assert_false(dash, "no dash")
	assert_gt(w.fighters[0].x, x0)

func test_briggs_has_no_backdash() -> void:
	var w := _world("briggs", "kestrel", 300.0)
	for t in 20:
		w.step([TestKit._at(_double_tap("left"), t), WorldSim.neutral()])
		assert_ne(w.fighters[0].state, "dash")

# ---------------------------------------------------------------- armour

func test_armoured_heavy_absorbs_exactly_one_hit() -> void:
	var w := _world("briggs", "kestrel", 36.0)
	var armor_events := 0
	var still_attacking := true
	for t in 8:
		w.step([TestKit._at(TestKit.tap(0, H), t), TestKit._at({ 3: TestKit.btn(L), 4: WorldSim.neutral() }, t)])
		for e in w.events:
			if e.type == "hit" and e.get("armor", false): armor_events += 1
		if w.fighters[0].state != "attack": still_attacking = false
	var f: FighterSim = w.fighters[0]
	assert_eq(armor_events, 1, "one hit absorbed")
	assert_true(still_attacking, "the move goes on through the hit")
	assert_lt(f.hp, 1150)
	assert_eq(f.armor_left, 0)
	assert_false(f.armored(), "armour is spent: the next hit in startup is a normal hit")

func test_armour_needs_a_move_with_armour() -> void:
	assert_true(FighterSim.load_data("briggs").moves.H.has("armor"))
	assert_false(FighterSim.load_data("kestrel").moves.H.has("armor"))

# ---------------------------------------------------------------- command grab

func _grab(p2_input: Dictionary, p2_def := "kestrel") -> WorldSim:
	var w := _world("briggs", p2_def, 40.0)
	for t in 60: w.step([TestKit._at(TestKit.tap(0, S), t), TestKit._at(p2_input, t)])
	return w

func test_command_grab_beats_block_for_double_throw_damage() -> void:
	var g := _grab(TestKit.btn(BL))
	var n := _world("briggs", "kestrel", 40.0)
	for t in 60: n.step([TestKit._at(TestKit.tap(0, THROW), t), WorldSim.neutral()])
	var cmd: int = 900 - g.fighters[1].hp
	var normal: int = 900 - n.fighters[1].hp
	assert_gt(normal, 0)
	assert_eq(cmd, normal * 2, "S does twice the normal throw")

func test_command_grab_beats_crouch_block_too() -> void:
	var g := _grab(TestKit.btn(BL, { "down": true }))
	assert_lt(g.fighters[1].hp, 900)

func test_command_grab_whiffs_on_a_jumping_defender() -> void:
	var w := _world("briggs", "kestrel", 40.0)
	w.fighters[1].state = "air"; w.fighters[1].y = 40.0; w.fighters[1].vy = 6.0
	for t in 14: w.step([TestKit._at(TestKit.tap(0, S), t), WorldSim.neutral()])
	assert_eq(w.fighters[1].hp, 900)
	assert_ne(w.fighters[1].state, "thrown")

func test_command_grab_cannot_be_teched() -> void:
	var w := _world("briggs", "kestrel", 40.0)
	var grab := -1
	var tech := false
	for t in 60:
		var p2 := WorldSim.neutral()
		if grab >= 0 and t == grab + 4: p2 = TestKit.btn(THROW)
		w.step([TestKit._at(TestKit.tap(0, S), t), p2])
		for e in w.events:
			if e.type == "grab" and grab < 0: grab = t
			if e.type == "tech": tech = true
	assert_gt(grab, 0)
	assert_false(tech)
	assert_lt(w.fighters[1].hp, 900)

func test_normal_throw_can_still_be_teched() -> void:
	var w := _world("briggs", "kestrel", 40.0)
	var grab := -1
	var tech := false
	for t in 60:
		var p2 := WorldSim.neutral()
		if grab >= 0 and t == grab + 4: p2 = TestKit.btn(THROW)
		w.step([TestKit._at(TestKit.tap(0, THROW), t), p2])
		for e in w.events:
			if e.type == "grab" and grab < 0: grab = t
			if e.type == "tech": tech = true
	assert_true(tech)

# ---------------------------------------------------------------- KESTREL dash punch

func test_kestrel_special_tip_is_plus_on_block() -> void:
	var m: Dictionary = FighterSim.load_data("kestrel").moves.S
	var tip: Dictionary = m.hits[1]
	var close: Dictionary = m.hits[0]
	var total := int(m.startup) + int(m.active) + int(m.recovery)
	assert_gt(int(tip.blockstun) - (total - int(tip.from)), 0, "tip hit is plus on block")
	assert_lt(int(close.blockstun) - (total - int(close.from)), 0, "close hit is minus on block")

# ---------------------------------------------------------------- rollback

func test_new_state_survives_save_restore() -> void:
	var w := _world("kestrel", "briggs", 300.0)
	for t in 6: w.step([TestKit._at(_double_tap("right"), t), WorldSim.neutral()])
	var snap := w.fighters[0].save()
	var before: Dictionary = snap.duplicate(true)
	for t in 10: w.step([TestKit._at(_double_tap("right"), t + 6), WorldSim.neutral()])
	w.fighters[0].restore(snap)
	assert_eq_deep(w.fighters[0].save(), before)
	for key in ["tap_dir", "tap_t", "dash_req", "dash_dir", "dash_speed", "hop", "armor_left", "throw_notech", "prev_rel"]:
		assert_true(snap.has(key), key)

# ---------------------------------------------------------------- CPU

func test_tier8_briggs_command_grabs_a_blocking_player() -> void:
	var w := _world("briggs", "kestrel", 40.0)
	var brain := CpuBrain.new(8, 0, 3)
	var grabs := 0
	for t in 400:
		w.step([brain.think(w.fighters), TestKit.btn(BL)])
		for e in w.events:
			if e.type == "grab" and e.att == 0 and w.fighters[0].cur.get("id", "") == "S": grabs += 1
	assert_gt(grabs, 0, "tier 8 goes for the command grab against a guard")

func test_cpu_kestrel_dashes_to_close_a_big_gap() -> void:
	var w := _world("kestrel", "briggs", 300.0)
	var brain := CpuBrain.new(8, 0, 5)
	var dashed := false
	for t in 600:
		w.step([brain.think(w.fighters), WorldSim.neutral()])
		if w.fighters[0].state == "dash": dashed = true
	assert_true(dashed)

func test_both_fighters_startup_fields_match_hit_windows() -> void:
	for fid in ["kestrel", "briggs"]:
		var data := FighterSim.load_data(fid)
		for id in data.moves:
			var m: Dictionary = data.moves[id]
			if not m.has("hits") or m.hits.is_empty(): continue
			var d := FrameData.derive(m)
			assert_eq(int(m.startup), d.startup, "%s %s startup" % [fid, id])
			assert_eq(int(m.active), d.active, "%s %s active" % [fid, id])

# ---------------------------------------------------------------- placeholder kits

func test_every_accessory_prop_in_the_looks_exists() -> void:
	for mid in ["a0", "briggs"]:
		for acc in FighterView.look_of(mid).get("accessories", []):
			assert_true(ResourceLoader.exists("res://fighters/shared/props/%s.tscn" % acc.prop), "%s: %s" % [mid, acc.prop])

func test_signature_silhouettes() -> void:
	var props := func(mid: String) -> Array: return FighterView.look_of(mid).accessories.map(func(a): return a.prop)
	for p in ["big_gauntlet", "apron", "boot", "moustache"]: assert_true(props.call("briggs").has(p), "BRIGGS " + p)
	for p in ["coat_front", "coat_back", "piston_gauntlet", "goggles", "belt"]: assert_true(props.call("a0").has(p), "KESTREL " + p)
	assert_eq(props.call("a0").count("piston_gauntlet"), 2, "piston gauntlets on both forearms")

func test_briggs_heavy_box_matches_the_bigger_fist() -> void:
	var k: Array = FighterSim.load_data("kestrel").moves.H.hits[0].box
	var b: Array = FighterSim.load_data("briggs").moves.H.hits[0].box
	assert_gt(int(b[2]) * int(b[3]), int(k[2]) * int(k[3]))
