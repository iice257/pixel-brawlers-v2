class_name AnimContract
## The animation names every fighter must provide (docs/GODOT_PLAN.md "Animation contract").
## A sprite pack is mapped onto these names by fighters/<id>/anim_map.tres; one extra entry per move id in the fighter's move list.

const REQUIRED := [
	"idle", "walk_f", "walk_b", "crouch", "jump_up", "jump_f", "jump_b",
	"block_stand", "block_crouch", "hit_light", "hit_heavy", "knockdown", "wakeup", "ko", "win",
]

## Names the map is missing for this move list (empty = contract met).
static func missing(map: AnimMap, move_ids: Array) -> Array:
	var out := []
	for n in REQUIRED + move_ids:
		if not map.entries.has(n): out.append(n)
	return out
