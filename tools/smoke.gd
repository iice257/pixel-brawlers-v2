extends SceneTree
## Headless smoke test: godot --headless --path . --script res://tools/smoke.gd
## Loads the main scene, runs a few frames, checks the input actions exist, exits non-zero on failure.

func _initialize() -> void:
	var ok := true
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	if scene == null:
		push_error("main scene failed to load"); ok = false
	else:
		root.add_child(scene.instantiate())
	await process_frame
	await process_frame
	for p in ["p1", "p2"]:
		for a in ["up", "down", "left", "right", "light", "medium", "heavy", "special", "block", "throw"]:
			if not InputMap.has_action("%s_%s" % [p, a]):
				push_error("missing action %s_%s" % [p, a]); ok = false
	print("SMOKE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
