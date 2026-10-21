extends GutTest
## G1: the frame data derived from data/fighters/<id>.json (the same derivation the box editor shows) matches docs/MOVES.md within 1 tick,
## and the sim agrees with the table for the first active tick.

func _table() -> Dictionary:
	var rows := {}
	var text := FileAccess.get_file_as_string("res://docs/MOVES.md")
	for line in text.split("\n"):
		if not line.begins_with("| "): continue
		var c: PackedStringArray = line.split("|")
		var move := c[1].strip_edges()
		if move == "Move" or not c[3].strip_edges().is_valid_int(): continue
		rows[move] = { "startup": int(c[3]), "active": int(c[4]), "recovery": int(c[5]), "dmg": int(c[6]) }
		var ah := c[8].strip_edges(); var ab := c[9].strip_edges()
		if ah.is_valid_int(): rows[move]["adv_hit"] = int(ah)
		if ab.is_valid_int(): rows[move]["adv_block"] = int(ab)
	return rows

func test_moves_doc_lists_every_move() -> void:
	var data := FighterSim.load_data("placeholder")
	var rows := _table()
	for id in data.moves: assert_true(rows.has(id), "MOVES.md has a row for %s" % id)
	assert_eq(rows.size(), data.moves.size(), "no stray rows")

func test_derived_frame_data_matches_moves_doc() -> void:
	var data := FighterSim.load_data("placeholder")
	var rows := _table()
	for id in data.moves:
		var d := FrameData.derive(data.moves[id])
		var r: Dictionary = rows[id]
		for k in ["startup", "active", "recovery"]:
			assert_true(absi(int(d[k]) - int(r[k])) <= 1, "%s %s: data %d vs MOVES.md %d" % [id, k, d[k], r[k]])
		for k in ["adv_hit", "adv_block"]:
			if r.has(k): assert_true(absi(int(d[k]) - int(r[k])) <= 1, "%s %s: data %d vs MOVES.md %d" % [id, k, d[k], r[k]])

func test_startup_field_matches_hit_window() -> void:
	var data := FighterSim.load_data("placeholder")
	for id in data.moves:
		var m: Dictionary = data.moves[id]
		if not m.has("hits") or m.hits.is_empty(): continue
		var d := FrameData.derive(m)
		assert_eq(int(m.startup), d.startup, "%s startup field equals the hit window start - 1" % id)
		assert_eq(int(m.active), d.active, "%s active field equals the hit window length" % id)

func test_sim_first_active_tick_matches_table() -> void:
	var rows := _table()
	var w := TestKit.arena()
	var t := TestKit.first_tick(w, 40, TestKit.tap(0, SimConst.L), {}, func(wo): return wo.fighters[1].hp < 1000)
	assert_eq(t, int(rows["L"].startup), "light connects on the first active tick = startup")
