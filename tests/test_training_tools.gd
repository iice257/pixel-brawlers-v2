extends GutTest
## Training readouts: numpad input notation with history, and frame advantage timing.

func _in(l := false, r := false, u := false, d := false, b := 0) -> Dictionary:
	var i := WorldSim.neutral()
	i.left = l; i.right = r; i.up = u; i.down = d; i.buttons = b
	return i

func test_numpad_and_buttons() -> void:
	assert_eq(TrainingTools.input_text(_in()), "5")
	assert_eq(TrainingTools.input_text(_in(false, true)), "6")
	assert_eq(TrainingTools.input_text(_in(true, false, false, true)), "1")
	assert_eq(TrainingTools.input_text(_in(false, true, true)), "9")
	assert_eq(TrainingTools.input_text(_in(true, true)), "5", "opposites cancel")
	assert_eq(TrainingTools.input_text(_in(false, false, false, true, SimConst.L | SimConst.H)), "2+LH")

func test_history_merges_repeats_and_caps() -> void:
	var t := TrainingTools.new()
	for n in 5: t.record_input(_in())
	t.record_input(_in(false, true))
	assert_eq(t.history.size(), 2)
	assert_eq(t.history[1].ticks, 5)
	for n in 20:
		t.record_input(_in(false, false, false, false, SimConst.L)); t.record_input(_in())
	assert_eq(t.history.size(), TrainingTools.HISTORY)

class FakeFighter:
	var free := false
	func actionable() -> bool: return free

func test_frame_advantage_signs() -> void:
	var t := TrainingTools.new()
	var a := FakeFighter.new(); var d := FakeFighter.new()
	t.on_contact(0, 1)
	t.update([a, d], 10)
	a.free = true; t.update([a, d], 11)
	d.free = true; t.update([a, d], 14)
	assert_eq(t.adv_text, "+3", "attacker free 3 ticks earlier")
	assert_true(t.adv_positive())
	a.free = false; d.free = false
	t.on_contact(0, 1)
	d.free = true; t.update([a, d], 20)
	a.free = true; t.update([a, d], 25)
	assert_eq(t.adv_text, "-5")
	assert_false(t.adv_positive())

func test_advantage_expires_and_unresolved_is_dropped() -> void:
	var t := TrainingTools.new()
	var a := FakeFighter.new(); var d := FakeFighter.new()
	a.free = true; d.free = true
	t.on_contact(0, 1); t.update([a, d], 1)
	assert_eq(t.adv_text, "0")
	for n in TrainingTools.SHOW_TICKS: t.update([a, d], 2 + n)
	assert_eq(t.adv_left, 0)
	a.free = false; d.free = false
	t.on_contact(0, 1)
	for n in TrainingTools.GIVE_UP_TICKS + 2: t.update([a, d], 500 + n)
	assert_true(t._pend.is_empty())
