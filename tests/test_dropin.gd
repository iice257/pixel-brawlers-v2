extends GutTest
## A baked fighter is a drop-in: every model has the humanoid skeleton the shared animations target, and the presenter
## can pose it with no per-model code. Add a model with tools/bake_fighter.sh and it is picked up here.

const SHARED := "res://fighters/shared/anims.res"

func _models() -> Array:
	var out := []
	for d in DirAccess.get_directories_at("res://fighters"):
		if FileAccess.file_exists("res://fighters/%s/model.scn" % d): out.append(d)
	return out

func test_models_exist() -> void:
	assert_gt(_models().size(), 1, "at least two baked fighter models (drop-in proof)")

func test_every_model_has_the_bones_the_clips_drive() -> void:
	var lib: AnimationLibrary = load(SHARED)
	var bones := {}
	for clip in lib.get_animation_list():
		var a := lib.get_animation(clip)
		for t in a.get_track_count():
			bones[str(a.track_get_path(t)).get_slice(":", 1)] = true
	assert_gt(bones.size(), 40, "clips drive a humanoid set")
	for id in _models():
		var m: Node = (load("res://fighters/%s/model.scn" % id) as PackedScene).instantiate()
		add_child_autofree(m)
		var sk: Skeleton3D = m.get_node_or_null("Skeleton3D")
		assert_not_null(sk, "%s has Skeleton3D" % id)
		if sk == null: continue
		for b in bones: assert_gte(sk.find_bone(b), 0, "%s has bone %s" % [id, b])

func test_presenter_poses_any_model() -> void:
	for id in _models():
		var f := FighterSim.new("placeholder", 0, 288.0, 1)
		var v := FighterView.new()
		add_child_autofree(v)
		v.setup(f, id, 0.0)
		v.present(1.0 / 60.0, 1)
		assert_true(v.player.has_animation("Idle"), "%s plays shared clips" % id)
