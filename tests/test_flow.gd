extends GutTest
## Front end navigates title -> menu -> select -> stage -> VS -> fight with the keyboard alone.

func _press(action: String) -> void:
	var e := InputEventAction.new(); e.action = action; e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)
	e = InputEventAction.new(); e.action = action; e.pressed = false
	Input.parse_input_event(e)
	await wait_process_frames(2)

func _key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = true
	Input.parse_input_event(e)
	await wait_process_frames(2)

func test_keyboard_path_reaches_the_fight() -> void:
	var f: Flow = load("res://ui/flow.tscn").instantiate()
	add_child_autofree(f)
	await wait_seconds(0.6)
	await _key(KEY_ENTER)                               # title -> menu
	await wait_seconds(0.6)
	assert_not_null(f.screen)
	await _press("ui_accept")                           # VERSUS -> select
	await wait_seconds(0.8)
	assert_true(f.screen is Flow.Select, "character select after VERSUS")
	await _press("p1_light"); await _press("p2_light")  # both confirm
	await wait_seconds(0.8)
	assert_eq(f.picks.size(), 2)
	await _press("ui_accept")                           # stage -> VS
	await wait_seconds(0.8)
	await wait_seconds(2.2)                             # VS splash times out into the fight
	assert_not_null(f.fight, "fight instanced")
	assert_eq(f.fight.cfg.mode, "versus")
