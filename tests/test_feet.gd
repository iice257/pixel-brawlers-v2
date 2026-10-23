extends GutTest
## Feet stay planted: both feet on the floor in the standing and crouch poses, and a walking planted foot does not slide.

var _sk: Skeleton3D
var _ap: AnimationPlayer

func before_each() -> void:
	var m: Node3D = (load("res://fighters/a0/model.scn") as PackedScene).instantiate()
	add_child_autofree(m)
	_sk = m.get_node("Skeleton3D")
	_ap = AnimationPlayer.new(); m.add_child(_ap)
	_ap.root_node = _ap.get_path_to(m); _ap.add_animation_library("", load("res://fighters/shared/anims.res"))

func _pose(clip: String, t: float, key := {}) -> void:
	_ap.play(clip); _ap.seek(t, true); _ap.pause(); _ap.advance(0.0)
	await get_tree().process_frame
	PoseLib.apply(_sk, key)

func _foot(n: String) -> Vector3:
	return _sk.get_bone_global_pose(_sk.find_bone(n)).origin

func test_keyed_stances_have_both_feet_on_the_floor() -> void:
	for nm in ["guard", "crouch", "block_stand", "block_crouch"]:
		var b := PoseLib.base(nm)
		await _pose(b[0], b[1], PoseLib.key(nm, ""))
		assert_lt(absf(_foot("LeftFoot").y - _foot("RightFoot").y), 0.01, "%s: feet level" % nm)

func test_crouch_is_a_wide_low_stance() -> void:
	var b := PoseLib.base("crouch")
	await _pose(b[0], b[1], {})
	var stand := _sk.get_bone_global_pose(_sk.find_bone("Hips")).origin.y - minf(_foot("LeftFoot").y, _foot("RightFoot").y)
	await _pose(b[0], b[1], PoseLib.key("crouch", ""))
	var low := _sk.get_bone_global_pose(_sk.find_bone("Hips")).origin.y - minf(_foot("LeftFoot").y, _foot("RightFoot").y)
	assert_lt(low, stand * 0.72, "hips well below standing height")
	assert_gt(absf(_foot("LeftFoot").x - _foot("RightFoot").x), 0.3, "feet at least shoulder width apart")

func test_walk_planted_foot_does_not_slide() -> void:
	for pair in [["walk_f", 2.1], ["walk_b", 1.7]]:
		var body := float(pair[1]) * FighterView.WORLD_PER_PX * 60.0
		var rate := body / FighterView.WALK_STANCE_MPS
		var len := _ap.get_animation("Walk").length
		var dt := 1.0 / 12.0
		var fwd := 1.0 if pair[0] == "walk_f" else -1.0
		var worst := 0.0
		var prev := {}
		for i in 13:
			var t := fposmod(i * dt * rate, len)
			await _pose("Walk", t if fwd > 0.0 else len - t - 0.01)
			var cur := {"LeftFoot": _foot("LeftFoot"), "RightFoot": _foot("RightFoot")}
			if i > 0:
				for n in cur:
					if cur[n].y < 0.06 and prev[n].y < 0.06:
						worst = maxf(worst, absf(cur[n].z - prev[n].z + fwd * body * dt))
			prev = cur
		assert_lt(worst, 0.03, "%s: planted foot drifts under 3 cm per 12 fps step" % pair[0])

func _ext_pose(name: String, clock: float, speed := 0.0) -> void:
	if not _ap.has_animation_library("ext"): _ap.add_animation_library("ext", AnimSource.library())
	var r := AnimSource.resolve(name, 0.0, clock, speed)
	_ap.play(r[0]); _ap.seek(r[1], true); _ap.pause(); _ap.advance(0.0)
	await get_tree().process_frame

func test_mocap_idle_and_crouch_stand_level_on_the_floor() -> void:
	for pair in [["idle", 0.5], ["idle", 2.5], ["idle", 4.2], ["crouch", 0.0]]:
		await _ext_pose(pair[0], pair[1])
		assert_lt(absf(_foot("LeftFoot").y - _foot("RightFoot").y), 0.08, "%s at %s: feet level" % pair)

func test_mocap_walk_planted_foot_does_not_slide() -> void:
	if not _ap.has_animation_library("ext"): _ap.add_animation_library("ext", AnimSource.library())
	for pair in [["walk_f", 1.75], ["walk_b", 1.55]]:
		var body := float(pair[1]) * 1.0
		var fwd := 1.0 if pair[0] == "walk_f" else -1.0
		var dt := 1.0 / 12.0
		var errs: Array = []
		var prev := {}
		for i in 13:
			var e: Dictionary = AnimSource.doc().map[pair[0]]
			var len := AnimSource.library().get_animation(StringName(e.clip)).length
			var t := fposmod(i * dt * body / float(e.mps), len)   # un-stepped: the 12 fps cel hold is a look choice, this checks the stride itself
			_ap.play("ext/" + String(e.clip)); _ap.seek(t if fwd > 0.0 else len - t - 0.02, true); _ap.pause(); _ap.advance(0.0)
			await get_tree().process_frame
			var l := _foot("LeftFoot"); var r := _foot("RightFoot")
			var low := "LeftFoot" if l.y < r.y else "RightFoot"
			var cur := {"n": low, "p": l if low == "LeftFoot" else r}
			if i > 0 and prev.n == cur.n:
				errs.append(absf(cur.p.z - prev.p.z + fwd * body * dt))
			prev = cur
		errs.sort()
		assert_lt(float(errs[errs.size() / 2]), 0.02, "%s: typical planted-foot drift under 2 cm per 12 fps step" % pair[0])
		assert_lt(float(errs[errs.size() - 1]), 0.12, "%s: worst step (foot hand-over) under 12 cm" % pair[0])
