class_name AnimMap
extends Resource
## Maps animation-contract names to what a fighter's art provides.
## Each entry: { "sheet": "res://...png" or "", "frames": int, "fps": int, "loop": bool, "color": Color (placeholder tint) }.

@export var fighter_id := ""
@export var source := "placeholder"     # pack name, for docs/ASSETS.md
@export var entries: Dictionary = {}

static func load_for(fighter_id: String) -> AnimMap:
	return load("res://fighters/%s/anim_map.tres" % fighter_id) as AnimMap

func entry(name: String) -> Dictionary:
	return entries.get(name, entries.get("idle", {}))
