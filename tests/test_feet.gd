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
